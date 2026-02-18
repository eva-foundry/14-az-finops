# SharePoint Deployment Checklist
**Date**: 2026-02-17  
**Package**: FinOps Hubs Documentation  
**Status**: Ready for Upload

---

## Pre-Deployment Validation ✅ COMPLETE

- [x] All 8 HTML files generated
- [x] Navigation menu on all pages (8 links each)
- [x] Architecture diagrams embedded (3 images, 369KB file)
- [x] Automated tests passed (25/25)
- [x] Browser testing completed (file:// + HTTP)
- [x] PDCA evidence report created

---

## SharePoint Upload Steps

### Step 1: Navigate to SharePoint Folder
**URL**: Documents/AI Enabled Projects/GitHub PoC/14-az-finops/

### Step 2: Upload Files
**Files to Upload** (from `i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package\`):

- [ ] index.html (28.5 KB)
- [ ] 00-current-state-inventory.html (20.9 KB)
- [ ] 01-gap-analysis-finops-hubs.html (25.5 KB)
- [ ] 02-target-architecture-embedded.html (369.2 KB) ⚠️ **CRITICAL: Contains diagrams**
- [ ] 03-deployment-plan.html (36.4 KB)
- [ ] 04-backlog.html (31.3 KB)
- [ ] 05-evidence-pack.html (30.7 KB)
- [ ] PHASE1-DEPLOYMENT-CHECKLIST.html (38.0 KB)

**Total Size**: 580.5 KB

**Upload Method**:
1. Click "Upload" button in SharePoint
2. Select "Files"
3. Navigate to package folder
4. Select all 8 HTML files
5. Click "Open"
6. Wait for upload completion

### Step 3: Post-Upload Validation

**Open index.html in SharePoint**:
- [ ] Navigation menu displays (8 links visible)
- [ ] Azure gradient header renders correctly
- [ ] Home icon (🏠) displays

**Test Navigation Links** (click each):
- [ ] 🏠 Home → Opens index.html ✅
- [ ] 00 - Current State → Opens inventory page ✅
- [ ] 01 - Gap Analysis → Opens gap analysis ✅
- [ ] 02 - Architecture → Opens architecture ✅
- [ ] 03 - Deployment Plan → Opens deployment plan ✅
- [ ] 04 - Backlog → Opens backlog ✅
- [ ] 05 - Evidence → Opens evidence pack ✅
- [ ] Phase 1 Checklist → Opens checklist ✅

**Verify Architecture Diagrams**:
Open `02-target-architecture-embedded.html` and scroll to verify:
- [ ] Figure 1: High-Level Architecture (flowchart visible)
- [ ] Figure 2: Deployment Architecture (component diagram visible)
- [ ] Figure 3: Data Lineage (data flow diagram visible)

**Browser Console Check**:
- [ ] Press F12 to open developer tools
- [ ] Check Console tab for errors
- [ ] Expected: No errors or warnings

**Mobile Test** (optional):
- [ ] Open from mobile device or tablet
- [ ] Verify navigation menu works
- [ ] Verify diagrams scale correctly

### Step 4: Share with Team

**Set Permissions**:
- [ ] Share folder with AICOE team members
- [ ] Recommended: Read-only access
- [ ] Send email with SharePoint link

---

## Troubleshooting

### Issue: Diagrams Don't Display
**Symptoms**: 
- Architecture page shows text but no diagrams
- 02-target-architecture-embedded.html loads but images missing

**Diagnosis**:
1. Check file size in SharePoint - should be ~369KB
2. If smaller (~50KB), wrong file was uploaded

**Resolution**:
1. Delete uploaded file from SharePoint
2. Re-upload from: `i:\eva-foundation\14-az-finops\docs\finops\sharepoint-package\02-target-architecture-embedded.html`
3. Verify file size after upload

### Issue: Navigation Links Don't Work
**Symptoms**: Clicking links does nothing or shows 404 error

**Diagnosis**: Files uploaded to wrong SharePoint folder

**Resolution**:
1. Ensure all 8 HTML files are in same SharePoint folder
2. Verify folder path: Documents/AI Enabled Projects/GitHub PoC/14-az-finops/
3. Re-upload if needed

### Issue: Styling Looks Wrong
**Symptoms**: No colors, no gradient header, plain text appearance

**Diagnosis**: SharePoint HTML viewer may have compatibility issue

**Resolution**:
1. Try opening in different browser (Edge, Chrome, Firefox)
2. Check if SharePoint has HTML rendering restrictions
3. Contact SharePoint admin if issue persists

---

## Success Criteria

**Deployment is successful when**:
- ✅ All 8 files visible in SharePoint folder
- ✅ index.html opens with navigation menu
- ✅ All 8 navigation links work (no 404 errors)
- ✅ Architecture page displays 3 diagrams
- ✅ Browser console shows no errors
- ✅ Team members can access files

---

## Post-Deployment Actions

- [ ] Send notification email to team with SharePoint URL
- [ ] Add link to EVA-JP project documentation
- [ ] Schedule review meeting to walk through documentation
- [ ] Create feedback channel for documentation improvements
- [ ] Plan regular updates (monthly?) as FinOps implementation progresses

---

## Evidence Collection

**Capture screenshots for records**:
- [ ] SharePoint folder showing all 8 files
- [ ] index.html rendered in SharePoint
- [ ] Architecture page with diagrams visible
- [ ] Browser console (F12) showing no errors
- [ ] Mobile view (if tested)

**Save to**: `test-evidence/sharepoint-deployment-screenshots/`

---

## Contacts

**Technical Support**:
- Package Creator: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)
- SharePoint Admin: [Your SharePoint admin contact]
- AICOE Team Lead: [Team lead contact]

**Issue Reporting**:
- Email: marco.presta@hrsdc-rhdcc.gc.ca
- Subject: "FinOps Documentation - SharePoint Issue"
- Include: Screenshot + browser console output

---

**Last Updated**: 2026-02-17 1:40 PM ET  
**Package Version**: 1.0  
**Test Results**: 25/25 passed (100%)
