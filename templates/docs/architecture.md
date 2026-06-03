# Architecture Overview

**Project:** [Name]
**Version:** 1.0
**Last Updated:** YYYY-MM-DD
**Author:** @name

> Living document — update when architectural decisions change.
> Reference ADRs in contexts/adrs/ for decision rationale.

---

## System Overview

[One-paragraph description of the system: what it does, who uses it, how it's structured at a high level.]

### Architecture Diagram

```
[Frontend]  ──→  [API Layer]  ──→  [Business Logic]  ──→  [Database]
                      ↓
               [External APIs]
                      ↓
                  [Queue/Cache]
```

---

## Technology Stack

| Layer | Technology | Version | ADR |
|-------|-----------|---------|-----|
| Frontend | [Framework] | vX.X | ADR-NNN |
| Backend | [Framework] | vX.X | ADR-NNN |
| Database | [DB] | vX.X | ADR-NNN |
| Cache | [Cache] | vX.X | ADR-NNN |
| Auth | [Auth] | vX.X | ADR-NNN |
| Deployment | [Platform] | - | ADR-NNN |

---

## Key Components

### [Component 1]

**Responsibility:** What this component does
**Owns:** Which files/directories
**Interfaces with:** Which other components
**Patterns used:** Repository, CQRS, etc.

### [Component 2]

...

---

## Data Model (High Level)

```
[Entity 1] 1──* [Entity 2]
[Entity 2] *──* [Entity 3] (via join table)
```

Key entities and their relationships. Full schema in db/schema.prisma (or equivalent).

---

## API Design

**Style:** REST | GraphQL | gRPC | tRPC
**Versioning:** URL path (/v1/) | Header | Query param
**Auth:** JWT | Session | API Key
**Rate limiting:** X req/min per user

Reference: ADR-NNN

---

## Authentication & Authorization

**Auth Provider:** [Provider]
**Strategy:** JWT | Session | OAuth2
**RBAC Roles:** admin | user | guest
**Permission check:** Middleware | Decorator | Guard

---

## Deployment Architecture

```
[User] → [CDN] → [Load Balancer] → [App Server x N] → [DB Primary]
                                                     → [DB Replica]
                                        ↕
                                    [Cache Layer]
                                        ↕
                                  [Queue/Workers]
```

**Platform:** [Cloud/VPS]
**CI/CD:** [Tool]
**Environments:** dev | staging | production

---

## Non-Functional Requirements

| Requirement | Target | Current |
|------------|--------|---------|
| API response time (p95) | < 200ms | - |
| Page load (LCP) | < 2.5s | - |
| Availability | 99.9% | - |
| Test coverage | ≥ 80% | - |

---

## Security Posture

- Auth: [approach]
- Input validation: [approach]
- Secrets management: [approach]
- Dependency scanning: [tool]
- See: contexts/adrs/ADR-NNN-security.md

---

## Known Trade-offs & Limitations

1. [Trade-off 1] — Accepted because [reason] — ADR-NNN
2. [Trade-off 2] — Plan to address in Phase [N]

---

## Glossary

| Term | Definition |
|------|-----------|
| [Term] | [Definition] |
