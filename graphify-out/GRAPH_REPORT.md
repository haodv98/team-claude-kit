# Graph Report - .  (2026-04-11)

## Corpus Check
- Corpus is ~3,616 words - fits in a single context window. You may not need a graph.

## Summary
- 29 nodes · 20 edges · 11 communities detected
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)
1. `AGENTS - Project Real Estate Manager` - 8 edges
2. `Plan → TDD → Review → Ship Workflow` - 4 edges
3. `Code Reviewer Agent` - 3 edges
4. `Context Management Playbook` - 2 edges
5. `Agentic OS Patterns Playbook` - 2 edges
6. `NestJS API Framework` - 2 edges
7. `Prisma ORM` - 2 edges
8. `Controller → Service → Repository → Prisma Pattern` - 2 edges
9. `CLAUDE - Project Brain` - 1 edges
10. `Prompt Patterns Playbook` - 1 edges

## Surprising Connections (you probably didn't know these)
- `AGENTS - Project Real Estate Manager` --references--> `NestJS API Framework`  [EXTRACTED]
  AGENTS.md → CLAUDE.md
- `AGENTS - Project Real Estate Manager` --references--> `Prisma ORM`  [EXTRACTED]
  AGENTS.md → CLAUDE.md
- `CLAUDE - Project Brain` --references--> `AGENTS - Project Real Estate Manager`  [EXTRACTED]
  CLAUDE.md → AGENTS.md
- `AGENTS - Project Real Estate Manager` --references--> `Next.js 16 Frontend`  [EXTRACTED]
  AGENTS.md → CLAUDE.md
- `AGENTS - Project Real Estate Manager` --references--> `PostgreSQL Database`  [EXTRACTED]
  AGENTS.md → CLAUDE.md

## Communities

### Community 0 - "Project Docs & Frontend Stack"
Cohesion: 0.29
Nodes (7): AGENTS - Project Real Estate Manager, CLAUDE - Project Brain, Next.js 16 Frontend, Playwright E2E Testing, PostgreSQL Database, Turborepo Monorepo, Vitest Testing Framework

### Community 1 - "Review & Planning Agents"
Cohesion: 0.29
Nodes (7): Code Reviewer Agent, Planner Agent, Security Reviewer Agent, TDD Guide Agent, TypeScript Reviewer Agent, API Response Envelope Format, Plan → TDD → Review → Ship Workflow

### Community 2 - "Core Prompt & Context Playbooks"
Cohesion: 0.67
Nodes (3): Prompt Patterns Playbook, Context Management Playbook, Memory Sessions Playbook

### Community 3 - "Team & Agentic OS Playbooks"
Cohesion: 0.67
Nodes (3): Team Workflows Playbook, Agentic OS Patterns Playbook, Daily Workflow Playbook

### Community 4 - "Backend Architecture & ORM"
Cohesion: 0.67
Nodes (3): Controller → Service → Repository → Prisma Pattern, NestJS API Framework, Prisma ORM

### Community 5 - "Version History"
Cohesion: 1.0
Nodes (1): CHANGELOG

### Community 6 - "Project Overview"
Cohesion: 1.0
Nodes (1): README

### Community 7 - "Architect Agent"
Cohesion: 1.0
Nodes (1): Architect Agent

### Community 8 - "Build Error Resolver"
Cohesion: 1.0
Nodes (1): Build Error Resolver Agent

### Community 9 - "E2E Test Agent"
Cohesion: 1.0
Nodes (1): E2E Runner Agent

### Community 10 - "Database Reviewer"
Cohesion: 1.0
Nodes (1): Database Reviewer Agent

## Knowledge Gaps
- **21 isolated node(s):** `CHANGELOG`, `README`, `CLAUDE - Project Brain`, `Prompt Patterns Playbook`, `Memory Sessions Playbook` (+16 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Version History`** (1 nodes): `CHANGELOG`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Project Overview`** (1 nodes): `README`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Architect Agent`** (1 nodes): `Architect Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Build Error Resolver`** (1 nodes): `Build Error Resolver Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `E2E Test Agent`** (1 nodes): `E2E Runner Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Database Reviewer`** (1 nodes): `Database Reviewer Agent`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AGENTS - Project Real Estate Manager` connect `Project Docs & Frontend Stack` to `Backend Architecture & ORM`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `Context Management Playbook` (e.g. with `Prompt Patterns Playbook` and `Memory Sessions Playbook`) actually correct?**
  _`Context Management Playbook` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `Agentic OS Patterns Playbook` (e.g. with `Team Workflows Playbook` and `Daily Workflow Playbook`) actually correct?**
  _`Agentic OS Patterns Playbook` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `CHANGELOG`, `README`, `CLAUDE - Project Brain` to the rest of the system?**
  _21 weakly-connected nodes found - possible documentation gaps or missing edges._