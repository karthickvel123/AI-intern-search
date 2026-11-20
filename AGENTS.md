# AGENTS.md

## Strict Project Rules

### Backend Architecture (`backend/`)
- **Runtime & Framework**: Python 3.11+, FastAPI, Pydantic v2.
- **Database & Storage**: Supabase (PostgreSQL with `pgvector` extension enabled for semantic search).
- **PDF Processing**: `pymupdf` (fitz) for resume and job description text/structure extraction.
- **AI & LLM Integration**: Official `google-genai` SDK using Structured JSON Output (schemas strictly defined via Pydantic).
- **Security**: Never expose LLM API keys, Supabase service keys, or backend secrets to the Flutter client. All AI generation, embedding calculation, and vector queries must be proxied through FastAPI endpoints.

### Client Architecture (`app/`)
- **Runtime & Framework**: Flutter 3.x with Material 3 styling.
- **State Management**: Riverpod (code generation / annotation style preferred).
- **Navigation & Routing**: GoRouter.
- **Networking & Serialization**: Dio + Freezed for immutable API models and JSON serialization.
- **Folder Structure**: Strict feature-first architecture:
  - `lib/features/{resume,feed,tailor,tracker,alerts}`
  - `lib/core/{theme,network,router,notifications}`

### AI Safety & Zero-Hallucination Rule
- Any AI-assisted resume tailoring MUST strictly rephrase, reorder, or highlight skills, experience, and projects that are already present in the user's parsed Master Profile.
- **Never** invent companies, metrics, roles, technologies, or achievements not backed by the user's actual profile data.

### Quality & Verification
- Always execute `dart analyze` after modifying or creating Dart files and resolve all errors and warnings before finishing.
