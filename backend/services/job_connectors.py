import abc
import asyncio
import re
import html
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional, Dict, Any
import httpx

from backend.models.job import JobListing

logger = logging.getLogger(__name__)

HTML_TAG_RE = re.compile(r"<[^>]+>")
YEARS_EXP_RE = re.compile(
    r"(?i)\b([3-9]|\d{2,})\+?\s*(?:-\s*\d+\s*)?(?:years?|yrs?)\b(?:\s+(?:of\s+)?experience)?"
)
INTERN_TITLE_RE = re.compile(r"(?i)\b(intern|internship|co-op|coop|trainee|student)\b")


def clean_html(raw_html: str) -> str:
    """Strips HTML tags and unescapes entities."""
    if not raw_html:
        return ""
    text = HTML_TAG_RE.sub(" ", raw_html)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def compute_ghost_job_flag(title: str, description: str, posted_at: Optional[datetime]) -> bool:
    """
    Computes ghost_job_flag:
    - True if job was posted > 30 days ago.
    - True if title indicates an internship/student role but asks for 3+ years of experience.
    """
    now = datetime.now(timezone.utc)

    # 1. Check if older than 30 days
    if posted_at is not None:
        if posted_at.tzinfo is None:
            posted_at = posted_at.replace(tzinfo=timezone.utc)
        if (now - posted_at) > timedelta(days=30):
            return True

    # 2. Check if titled "Intern" while demanding 3+ years experience
    if INTERN_TITLE_RE.search(title):
        if YEARS_EXP_RE.search(description):
            return True

    return False


class BaseJobConnector(abc.ABC):
    """Abstract connector interface for any job board or ATS."""

    @property
    @abc.abstractmethod
    def name(self) -> str:
        """Name of the connector."""
        pass

    @abc.abstractmethod
    async def fetch_jobs(self) -> List[JobListing]:
        """Fetches and normalizes job openings into JobListing models."""
        pass


class GreenhouseConnector(BaseJobConnector):
    """Connector for public Greenhouse Boards JSON API."""

    DEFAULT_COMPANIES = ["figma", "cloudflare", "stripe", "discord", "gusto", "brex", "affirm"]

    def __init__(self, company_slugs: Optional[List[str]] = None):
        self.company_slugs = company_slugs or self.DEFAULT_COMPANIES

    @property
    def name(self) -> str:
        return "Greenhouse"

    async def _fetch_single_company(self, client: httpx.AsyncClient, slug: str) -> List[JobListing]:
        results: List[JobListing] = []
        url = f"https://boards-api.greenhouse.io/v1/boards/{slug}/jobs?content=true"
        try:
            resp = await client.get(url)
            if resp.status_code != 200:
                return results

            data = resp.json()
            jobs = data.get("jobs", [])

            for item in jobs:
                job_id = str(item.get("id"))
                title = item.get("title", "").strip()
                if not title:
                    continue

                location_name = (item.get("location") or {}).get("name") or "Remote / Flexible"
                is_remote = bool("remote" in location_name.lower() or "remote" in title.lower())
                raw_content = item.get("content") or ""
                clean_desc = clean_html(raw_content)

                posted_str = item.get("updated_at")
                posted_at = None
                if posted_str:
                    try:
                        posted_at = datetime.fromisoformat(posted_str.replace("Z", "+00:00"))
                    except Exception:
                        pass

                company_display = slug.capitalize()
                ghost_flag = compute_ghost_job_flag(title, clean_desc, posted_at)

                listing = JobListing(
                    external_id=f"greenhouse:{slug}:{job_id}",
                    title=title,
                    company=company_display,
                    location=location_name,
                    is_remote=is_remote,
                    description=clean_desc[:4000] if clean_desc else f"Position for {title} at {company_display}.",
                    apply_url=item.get("absolute_url"),
                    source="Greenhouse",
                    posted_at=posted_at,
                    ghost_job_flag=ghost_flag,
                )
                results.append(listing)
        except Exception as exc:
            logger.warning(f"Error fetching Greenhouse jobs for {slug}: {exc}")
        return results

    async def fetch_jobs(self) -> List[JobListing]:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) InternPulse/1.0"}
        async with httpx.AsyncClient(timeout=8, headers=headers, follow_redirects=True) as client:
            tasks = [self._fetch_single_company(client, slug) for slug in self.company_slugs]
            nested_results = await asyncio.gather(*tasks, return_exceptions=True)
            flat_results: List[JobListing] = []
            for res in nested_results:
                if isinstance(res, list):
                    flat_results.extend(res)
            return flat_results


class LeverConnector(BaseJobConnector):
    """Connector for public Lever Postings JSON API."""

    DEFAULT_COMPANIES = ["spotify", "netflix", "palantir", "atlassian", "twitch"]

    def __init__(self, company_slugs: Optional[List[str]] = None):
        self.company_slugs = company_slugs or self.DEFAULT_COMPANIES

    @property
    def name(self) -> str:
        return "Lever"

    async def _fetch_single_company(self, client: httpx.AsyncClient, slug: str) -> List[JobListing]:
        results: List[JobListing] = []
        url = f"https://api.lever.co/v0/postings/{slug}?mode=json"
        try:
            resp = await client.get(url)
            if resp.status_code != 200:
                return results

            postings = resp.json()
            if not isinstance(postings, list):
                return results

            for item in postings:
                job_id = str(item.get("id"))
                title = item.get("text", "").strip()
                if not title:
                    continue

                categories = item.get("categories") or {}
                location_name = categories.get("location") or "Remote / Unspecified"
                workplace_type = str(item.get("workplaceType") or "").lower()
                is_remote = bool("remote" in workplace_type or "remote" in location_name.lower() or "remote" in title.lower())

                desc_plain = item.get("descriptionPlain") or ""
                additional_plain = item.get("additionalPlain") or ""
                full_desc = (desc_plain + "\n\n" + additional_plain).strip()

                created_ts = item.get("createdAt")
                posted_at = None
                if created_ts and isinstance(created_ts, (int, float)):
                    try:
                        posted_at = datetime.fromtimestamp(created_ts / 1000.0, tz=timezone.utc)
                    except Exception:
                        pass

                company_display = slug.capitalize()
                ghost_flag = compute_ghost_job_flag(title, full_desc, posted_at)

                listing = JobListing(
                    external_id=f"lever:{slug}:{job_id}",
                    title=title,
                    company=company_display,
                    location=location_name,
                    is_remote=is_remote,
                    description=full_desc[:4000] if full_desc else f"Opening for {title} at {company_display}.",
                    apply_url=item.get("hostedUrl") or item.get("applyUrl"),
                    source="Lever",
                    posted_at=posted_at,
                    ghost_job_flag=ghost_flag,
                )
                results.append(listing)
        except Exception as exc:
            logger.warning(f"Error fetching Lever jobs for {slug}: {exc}")
        return results

    async def fetch_jobs(self) -> List[JobListing]:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) InternPulse/1.0"}
        async with httpx.AsyncClient(timeout=8, headers=headers, follow_redirects=True) as client:
            tasks = [self._fetch_single_company(client, slug) for slug in self.company_slugs]
            nested_results = await asyncio.gather(*tasks, return_exceptions=True)
            flat_results: List[JobListing] = []
            for res in nested_results:
                if isinstance(res, list):
                    flat_results.extend(res)
            return flat_results


def get_default_connectors() -> List[BaseJobConnector]:
    """Returns the default active connectors list."""
    return [
        GreenhouseConnector(),
        LeverConnector(),
    ]
