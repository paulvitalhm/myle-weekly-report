# Current Sprint: Checks and Recovery

## Startup Checks (Phase 1 - ALWAYS RUN FIRST)

Before any task:

1. **Context Directory Check**
   - If /context/ missing/empty: "No context/ found. Add PRD/screenshots now? (yes/no)"
   - Wait for explicit response before proceeding

2. **Project Rules Check**
   - If .clinerules/ missing: "No .clinerules/ found. Copy default from ../common-assets-for-cline/.clinerules/? (yes/no)"
   - Wait for response before proceeding

3. **Agentic Exploration**
   - Read /context/ first (PRD, screenshots)
   - List/search/read relevant codebase files
   - Never assume - verify everything

## Recovery After Context Loss

Check IMPLEMENTATION_PLAN.md > Changelog:
- Find last completed phase
- Resume from next unchecked task
- Re-explore if needed (include /context/)

## Business Context

- Site: https://mylehomeservices.com/
- Goal: Lead gen apps <5 min completion
- Always bilingual FR/EN
- Mobile-first design

## Post-Project Learnings (OPTIONAL)

After completing major projects, consider creating:
`C:\Users\hiolm\OneDrive\Documents\GitHub\common-assets-for-cline\learnings\YYYY-MM-DD-project-name-learnings.md`

Include:
- Critical bugs and solutions
- Framework-specific gotchas
- Architecture decisions
- Reusable checklists
