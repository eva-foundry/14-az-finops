# Subscription Assessment - Decision Framework & Priority Matrix
**Date**: March 3, 2026  
**Audience**: AICOE Leadership, Project 14 Owner (Phase 4 Planning)  
**Basis**: Full subscription inventory + finopsAnalysis + organizational context

---

## EXECUTIVE DECISION MATRIX

| Recommendation | Annual Savings | Effort Hours | Risk | Timeline | Status | GO/NO-GO |
|---|---|---|---|---|---|---|
| **1. Dev Premium SKU Downgrade** | $11K-$12K | 2-3 | LOW | This week | Ready | **GO** (start now) |
| **2. ACR Consolidation** | $7K-$15K | 4-6 | MEDIUM | 2-4 weeks | Ready | **GO** (after audit) |
| **3. Search Services Downgrade** | $1K-$1.4K | 3-4 | MEDIUM | 2-3 weeks | Needs validation | **CONDITIONAL** (needs metrics) |
| **4. RBAC Cleanup** | Governance | 8-10 | MEDIUM | 3-4 weeks | Ready | **GO** (parallel track) |
| **5. Reusability Standardization** | Cascading benefit | 6-8 wks | LOW | Weeks 5-12 | Strategic | **DEFER** (Phase 4.2) |
| **6. InfoAssist Consolidation** | $25K-$55K | Strategic | HIGH | Q2 2026 | Org decision | **REQUIRES SIGN-OFF** |

**Total Year 1 Direct Savings (All High-Priority Items)**: $19K-$28.4K  
**Total Year 1 + Cascading (If InfoAssist approved)**: $44K-$83.4K

---

## DECISION TREE: WHICH RECOMMENDATIONS APPLY TO YOU?

### Path A: Cost-Focused (Want immediate, measurable ROI)
→ **Start with**: Dev Premium SKU Downgrade (#1) + ACR Consolidation (#2)  
→ **Then**: Search Services (#3) if metrics support it  
→ **Expected Year 1 Total**: $19K-$28.4K  
→ **Timeline**: 2-6 weeks  
→ **Effort**: 9-13 hours

### Path B: Governance-Focused (Want compliance + cost transparency)
→ **Start with**: RBAC Cleanup (#4) + Reusability Standardization (#5)  
→ **Then**: SKU downgrades as parallel efficiency (cost management)  
→ **Expected Year 1 Total**: Compliance + $7K-$12K  
→ **Timeline**: 4-12 weeks  
→ **Effort**: 14-18 hours

### Path C: Strategic Transformation (Want to reshape InfoAssist portfolio)
→ **Start with**: Full assessment (already done) + leadership alignment  
→ **Then**: Conditional InfoAssist consolidation decision  
→ **Expected Year 1 Total**: $25K-$55K (if approved)  
→ **Timeline**: Q2 2026 planning  
→ **Effort**: 3-6 weeks for decision, + 8-12 weeks for execution

### Path D: Balanced (Default Recommendation)
→ **Go to**: **Recommended Sequencing** section below

---

## RECOMMENDED SEQUENCING (Default Path)

### **PHASE 1: Quick Wins (Week of March 3-7)**

**What to do**:
1. Dev Premium SKU Downgrade (#1)
2. Start ACR Audit (#2 - information gathering only)

**Effort**: 2-3 hours core work, minimal interruption  
**Expected Savings**: $11K-$12K/yr  
**Decision Required**: None (low-risk, immediate benefit)

**Execute with**:
```
$ Run: IMPLEMENTATION-PLAYBOOK-20260303.md PLAYBOOK 1
$ Owner: AICOE Platform Engineer (1 person)
$ Verification: 2-day monitoring post-downgrade
```

---

### **PHASE 2: Medium-Effort, High-Impact (Week of March 10-21)**

**What to do**:
1. Complete ACR Consolidation audit (#2)
2. Start Search Services metrics collection (#3)
3. Begin RBAC cleanup (#4)

**Effort**: 4-10 hours (distributed)  
**Expected Savings**: $7K-$15K/yr (ACR) + $1K-$1.4K/yr (Search)  
**Decision Required**: 
- ACR: Which registries to consolidate? (based on audit results)
- Search: Which services to downgrade? (based on query metrics)
- RBAC: Approval to remove stale assignments? (compliance/security review)

**Execute with**:
```
$ Run: IMPLEMENTATION-PLAYBOOK-20260303.md PLAYBOOKS 2-4
$ Owner: Platform team (2-3 people, part-time)
$ Timeline: 2-4 weeks (parallel tracks)
```

---

### **PHASE 3: Strategic Decision (Week of March 24-31)**

**Decision Point: InfoAssist Consolidation**

**Trigger**: Complete Phases 1 & 2, validate cost savings  
**Stakeholders**: 
- Todd Whitley (Financial Authority)
- Niasha Blake (Cost Center Owner)
- InfoAssist Product Owner
- AICOE Platform Lead

**Meeting Agenda** (30 minutes):
1. Present Phase 1-2 results ($18K-$27K identified)
2. Present InfoAssist scenario: Current vs. Consolidated
3. Ask: What is the organizational appetite for environment consolidation?
4. Document decision (Go/No-Go) for Q2 planning

**Possible Outcomes**:
- ✅ **GO**: Schedule Phase 4 (Q2 execution, estimated $25K-$55K/yr)
- ❌ **NO-GO**: Continue with Phases 1-2 only ($19K-$28K/yr target)
- ⏸️ **DEFER**: Agree to revisit in Q3 after testing new infrastructure

---

### **PHASE 4: Organizational Alignment (Q2 2026)**

**If InfoAssist Consolidation approved**:
- Design shared staging environment architecture
- Plan InfoAssist team migration/collaboration model
- Execute consolidation (8-12 weeks)
- Realize $25K-$55K/yr savings

**If InfoAssist NOT approved**:
- Continue standard optimization (RBAC, tagging, monitoring)
- Plan next assessment for Q3 2026

---

## DECISION CRITERIA: GO / NO-GO FOR EACH ITEM

### Item #1: Dev Premium SKU Downgrade
**Recommendation**: ✅ **GO** (unconditional)

**Why**: 
- Risk is minimal (dev environments, reversible in 10 minutes)
- Savings are guaranteed ($11K-$12K/yr)
- No dependencies (can execute immediately)
- Aligns with FinOps best practices (no premium tiers for non-prod)

**Go/No-Go Criteria**:
- Go if: (almost always yes) -- resource is in a dev/test RG and not actively providing business value in Premium tier
- No-Go if: Resource owner explicitly objects OR queries show critical performance need (rare)

**Owner**: AICOE Platform Team  
**Timeline**: This week  
**Approval**: No formal approval needed (low-risk operations)

---

### Item #2: ACR Consolidation
**Recommendation**: ✅ **GO** (conditional on audit results)

**Why**:
- Savings are moderate-to-high ($7K-$15K/yr depending on scope)
- Container images are ephemeral (can be rebuilt if audit goes wrong)
- Reduces operational overhead (fewer registries to manage)
- Aligns with consolidation strategy across InfoAssist projects

**Go/No-Go Criteria**:
- Go if: Audit shows 4+ "dead" ACRs (no images or no pulls in 90 days)
- Conditional if: 2-3 dead ACRs, OR active duplicates (need owner consent for migration)
- No-Go if: All 17 ACRs are actively used AND no duplicates found

**Owner**: AICOE Platform Team  
**Timeline**: 
- Audit: This week (1-2 hours)
- Migration/Deletion: Week 2-4 (depends on audit results)
**Approval**: Platform team consensus + cost center owner sign-off for dead registry deletion

---

### Item #3: Search Services Downgrade
**Recommendation**: ⏸️ **CONDITIONAL** (need to validate metrics first)

**Why**:
- Savings are modest ($1K-$1.4K/yr)
- Risk is medium (potential search latency increase if miscalculated)
- Requires 30+ days of query data to validate

**Go/No-Go Criteria**:
- Go if: Metrics show < 5 req/sec average AND < 2% throttling for candidate services
- No-Go if: Metrics show > 10 req/sec OR > 5% throttling

**Owner**: Application team (owners of Search Services) + Platform team  
**Timeline**: 
- Metrics collection: This week (1-2 hours)
- Decision: Week 2
- Execution (if Go): Week 3
**Approval**: Application owner (must validate functionality won't degrade)

---

### Item #4: RBAC Cleanup
**Recommendation**: ✅ **GO** (sequential with Phase 1-2)

**Why**:
- Governance benefit is high (security audit alignment, compliance)
- Risk is medium (can break automation if carelessly executed)
- Enables better cost attribution (licenses allocated to active identities only)

**Go/No-Go Criteria**:
- Go if: Security/Compliance team approves stale principal removal
- Conditional if: Need to validate business processes before removing assignments
- Trend: 90% of RBAC cleanups in similar organizations find 20-30% stale assignments

**Owner**: Security/Compliance team + AICOE Platform Admin  
**Timeline**: 
- Export & validation: Week 2 (2-3 hours)
- Cleanup execution: Week 3-4 (staggered, with monitoring)
**Approval**: Security team + Finance (RBAC impacts licensing)

---

### Item #5: Reusability Standardization
**Recommendation**: ⏸️ **DEFER** (Phase 4.2, not critical for Year 1)

**Why**:
- Strategic benefit is medium (enables future consolidations)
- Effort is high (6-8 weeks, requires policy setup)
- Cost savings are cascading (indirect), not direct

**Go/No-Go Criteria**:
- Go if: Organization is planning enterprise-wide resource governance (which would benefit from tagging)
- No-Go / Defer if: Tagging can come after cost optimization (sequences better)

**Owner**: Platform team (as part of broader governance initiative)  
**Timeline**: Weeks 5-12 (if approved in Phase 3 decision)  
**Approval**: Enterprise Architecture + Compliance

---

### Item #6: InfoAssist Environment Consolidation
**Recommendation**: ⏸️ **REQUIRES LEADERSHIP DECISION** (not technical, organizational)

**Why**:
- Savings are high ($25K-$55K/yr)
- Risk is high (impacts team workflows, requires stakeholder alignment)
- Decision rests with InfoAssist product owner + AICOE leadership

**Go/No-Go Criteria**:
- Go if: InfoAssist product owner agrees environment consolidation aligns with roadmap AND team can accept shared staging
- No-Go if: Teams need isolated environments for compliance/performance isolation
- Defer if: Want to pilot with 2-3 environments first (mid-tier option)

**Owner**: InfoAssist Product Owner + Todd Whitley (Financial Authority)  
**Timeline**: Decision in Week of March 24; execution in Q2 2026 (if Go)  
**Approval**: Leadership committee (not routine operations)

---

## ESTIMATED TIMELINE GANTT

```
Week 1 (Mar 3-7)      [#1 ACTIVE                    ]
Week 2 (Mar 10-14)    [     #2 audit    #4 start   ]
Week 3 (Mar 17-21)    [     #2 migrate  #4 active  #3 metrics]
Week 4 (Mar 24-28)    [                      DECISION POINT for #6]
Week 5-6 (Mar 31-Apr11)[    #5 (if approved in week 4)]
Q2 2026               [                           #6 (if Go) 8-12 wks]
```

---

## FINANCIAL IMPACT SUMMARY

### Scenario A: Cost-Optimized (High-Priority Only)
| Item | Savings | Timeline | Status |
|---|---|---|---|
| #1 Dev SKU Downgrade | $11K-$12K | Week 1 | ✅ GO |
| #2 ACR Consolidation | $7K-$15K | Weeks 2-4 | ✅ GO (audit-dependent) |
| #3 Search Downgrade | $1K-$1.4K | Weeks 2-3 | ⏸️ CONDITIONAL |
| **Total Year 1** | **$19K-$28.4K** | **4 weeks** | **Ready** |

**ROI**: $4,750-$7,100/week for first month (operations team time is ~$500/week)

### Scenario B: Governance-Enhanced (All recommendations)
| Item | Benefit | Timeline | Status |
|---|---|---|---|
| Scenario A items | $19K-$28.4K | Weeks 1-4 | ✅ |
| #4 RBAC Cleanup | Compliance + potential licensing savings | Weeks 2-4 | ✅ |
| #5 Tagging Standardization | Foundation for future consolidations | Weeks 5-12 | ⏸️ |
| **Total Year 1** | **$19K-$28.4K (direct) + Governance** | **12 weeks** | **Scalable** |

### Scenario C: Transformative (With InfoAssist)
| Item | Savings | Timeline | Status |
|---|---|---|---|
| Scenario A items | $19K-$28.4K | Weeks 1-4 | ✅ |
| #6 InfoAssist Consolidation | $25K-$55K | Q2 2026 (8-12 wks) | ⏸️ DECISION |
| **Total Year 1** | **$44K-$83.4K** | **16-20 weeks** | **Conditional** |

---

## DISCUSSION PROMPTS FOR LEADERSHIP

### If pursuing Scenario A (Cost-Optimized):
1. "Are we comfortable downgrading dev Premium resources this week?"
2. "Which 2-3 ACRs would you like audited first for consolidation?"
3. "Can we start Search Services metrics collection in parallel?"

### If pursuing Scenario B (Governance-Enhanced):
1. "How much operational overhead is infrastructure RBAC creating?"
2. "Should we implement mandatory resource tagging across all projects?"
3. "Would tagging enable better chargeback/cost allocation?"

### If considering Scenario C (Transformative):
1. "What is the strategic value of consolidating InfoAssist environments?"
2. "Can INFO-assist teams accept shared staging, or do they need isolation?"
3. "Should this come in Phase 4 (this quarter) or Phase 5 (next quarter)?"

---

## RISK MITIGATION

### Mitigation for #1 (Dev SKU Downgrade) - LOW RISK, but:
- **Risk**: Dev team complains about performance
- **Mitigation**: Revert in 10 minutes if needed; monitor for 2 days post-downgrade
- **Contingency**: App Service Premium ↔ Standard is reversible; no data loss

### Mitigation for #2 (ACR Consolidation) - MEDIUM RISK:
- **Risk**: Miss an actively-used ACR, delete it
- **Mitigation**: Audit for 90-day pull history; confirm with team before deletion
- **Contingency**: Images can be rebuilt from source; ACR recreation takes 5 minutes

### Mitigation for #3 (Search Downgrade) - MEDIUM RISK:
- **Risk**: Search latency increases post-downgrade, impact application
- **Mitigation**: Pull 30-day metrics FIRST; downgrade only if data supports it
- **Contingency**: Revert to Standard in 10 minutes if latency exceeds threshold

### Mitigation for #4 (RBAC Cleanup) - MEDIUM RISK:
- **Risk**: Remove assignment that a process depends on
- **Mitigation**: Validate principal existence in Entra ID FIRST; stagger removals
- **Contingency**: Re-add assignment in 2 minutes if alarm fires

### Mitigation for #6 (InfoAssist Consolidation) - HIGH RISK:
- **Risk**: Teams blocked from working during migration
- **Mitigation**: Plan during low-traffic period; full rollback plan required
- **Contingency**: Requires parallel environments during transition (8-12 week effort)

---

## APPROVAL SIGN-OFF

### For Scenario A (Go/No-Go This Week):

```
[  ] Todd Whitley (Financial Authority): Approve Dev SKU Downgrade spending review?
[  ] AICOE Platform Lead: Approve Platform team effort allocation (2-3 hours)?
[  ] Project 14 Owner: This aligns with Phase 4 roadmap?
```

### For Scenario C (Strategic Decision):

```
[  ] Todd Whitley + Niasha Blake: Business case for InfoAssist consolidation?
[  ] InfoAssist Product Owner: Team readiness for shared environment?
[  ] AICOE Leadership: Commit to Q2 2026 execution if approved?
```

---

**Next Steps**:
1. Review this decision framework with AICOE leadership (30-min meeting)
2. Align on Scenario (A / B / C or custom path)
3. Publish decision, kick off Phase 1

**Document Location**: `eva-foundry/14-az-finops/DECISION-FRAMEWORK-20260303.md`

