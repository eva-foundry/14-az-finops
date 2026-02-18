# GitHub Copilot Instructions Template

**Template Version**: 2.1.0  
**Generated**: January 30, 2026, 2:00 PM EST  
**Last Updated**: January 30, 2026  
**Project Type**: {PROJECT_TYPE}  
**Based on**: EVA Professional Component Architecture Standards (from EVA-JP-v1.2 production learnings)

---

## Release Notes

### Version 2.1.0 (January 30, 2026)
**Breaking Changes**:
- Redesigned PART 2 from generic [TODO] format to AI-instructional placeholders
- Added [INSTRUCTION for AI] markers explaining what content to fill and why
- Introduced **[MANDATORY]** vs **[RECOMMENDED]** category markers for prioritization

**New Features**:
- 11 structured placeholder categories based on production analysis (EVA-JP-v1.2, MS-InfoJP)
- Enhanced placeholder syntax with examples: `[TODO: Add X - e.g., value format]`
- Quick Commands Table (action-oriented lookup)
- Azure Resource Inventory (subscription IDs, resource groups)
- Anti-Patterns sections (❌ FORBIDDEN patterns with explanations)
- Success Criteria / Testable Goals
- Performance/Timing Expectations
- Deployment Status & Known Issues tracking

**Improvements**:
- Template now generates AI instruction manual (not documentation)
- Placeholders show correct format/structure (imperative, conditional, reference patterns)
- Backward compatible: existing PART 2 sections remain valid
- Research-based design: 100% coverage of high-frequency patterns (Quick Commands, Environment Config, File Paths)

**Migration Notes**:
- Projects using v2.0.0 template can continue as-is
- New projects should use v2.1.0 structured placeholders
- Apply-Project07-Artifacts.ps1 v1.4.0+ compatible with both versions

### Version 2.0.0 (January 29, 2026)
**Breaking Changes**:
- Transformed from project-specific to reusable template
- Added comprehensive placeholder system for all project-specific values
- Enhanced with anti-patterns prevention and quality gates

**New Features**:
- Template Usage Instructions section
- Anti-Patterns Prevention section
- Emergency Debugging Protocol
- File Organization Requirements
- Quality Gates checklist

**Improvements**:
- Complete PART 1 preservation (universal best practices)
- Structured placeholder guidance in PART 2
- Professional component implementations remain intact
- Enhanced documentation structure

### Version 1.0.0 (January 9, 2026)
**Initial Production Release**:
- Universal best practices (PART 1)
- EVA-JP-v1.2 project-specific patterns (PART 2)
- Professional Component Architecture (DebugArtifactCollector, SessionManager, StructuredErrorHandler, ProfessionalRunner)
- Azure account management patterns
- Workspace housekeeping principles
- Encoding safety standards

---

## Table of Contents

### PART 1: Universal Best Practices
- [Encoding & Script Safety](#critical-encoding--script-safety)
- [Azure Account Management](#critical-azure-account-management)
- [AI Context Management](#ai-context-management-strategy)
- [Azure Services Inventory](#azure-services--capabilities-inventory)
- [Professional Component Architecture](#professional-component-architecture)
  - [DebugArtifactCollector](#implementation-debugartifactcollector)
  - [SessionManager](#implementation-sessionmanager)
  - [StructuredErrorHandler](#implementation-structurederrorhandler)
  - [ProfessionalRunner](#implementation-zero-setup-project-runner)
- [Professional Transformation](#professional-transformation-methodology)
- [Dependency Management](#dependency-management-with-alternatives)
- [Workspace Housekeeping](#workspace-housekeeping-principles)
- [Code Style Standards](#code-style-standards)

### PART 2: {PROJECT_NAME} Project Specific
- [Documentation Guide](#documentation-guide)
- [Architecture Overview](#architecture-overview)
- [Development Workflows](#development-workflows)
- [Project-Specific Automation](#project-specific-automation)
- [Critical Code Patterns](#critical-code-patterns)
- [Testing](#testing)
- [CI/CD Pipeline](#cicd-pipeline)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)

### PART 3: Quality & Safety
- [Anti-Patterns Prevention](#anti-patterns-prevention)
- [File Organization Requirements](#file-organization-requirements)
- [Quality Gates](#quality-gates)
- [Emergency Debugging Protocol](#emergency-debugging-protocol)

### PART 4: Template Usage
- [Template Usage Instructions](#template-usage-instructions)

---

## Quick Reference

**Most Critical Patterns**:
1. **Encoding Safety** - Always use ASCII-only in scripts (prevents UnicodeEncodeError in Windows cp1252)
2. **Azure Account** - Professional account {PROFESSIONAL_EMAIL} required for {ORGANIZATION} resources (configure based on your subscription)
3. **Component Architecture** - DebugArtifactCollector + SessionManager + StructuredErrorHandler + ProfessionalRunner
4. **Session Management** - Checkpoint/resume capability for long-running operations
5. **Evidence Collection** - Screenshots, HTML dumps, network traces at operation boundaries

**Professional Components** (Full Working Implementations):

| Component | Purpose | Key Methods |
|-----------|---------|-------------|
| **DebugArtifactCollector** | Capture HTML/screenshots/traces | `capture_state()`, `set_page()` |
| **SessionManager** | Checkpoint/resume operations | `save_checkpoint()`, `load_latest_checkpoint()` |
| **StructuredErrorHandler** | JSON error logging | `log_error()`, `log_structured_event()` |
| **ProfessionalRunner** | Zero-setup execution | `auto_detect_project_root()`, `validate_pre_flight()` |

**Where to Find Source**:
- Complete working system: `{PROJECT_IMPLEMENTATION_PATH}`
- Best practices reference: `{BEST_PRACTICES_PATH}`
- Framework architecture: `{FRAMEWORK_ARCHITECTURE_PATH}`

---

## PART 1: UNIVERSAL BEST PRACTICES

> **Applicable to any project, any scenario**  
> Critical patterns, Azure inventory management, workspace organization principles

### Critical: Encoding & Script Safety

**ABSOLUTE BAN: No Unicode/Emojis Anywhere**
- **NEVER use in code**: Checkmarks, X marks, emojis, Unicode symbols, ellipsis
- **NEVER use in reports**: Unicode decorations, fancy bullets, special characters
- **NEVER use in documentation**: Unless explicitly required by specification
- **ALWAYS use**: Pure ASCII - "[PASS]", "[FAIL]", "[ERROR]", "[INFO]", "[WARN]", "..."
- **Reason**: Enterprise Windows cp1252 encoding causes silent UnicodeEncodeError crashes
- **Solution**: Set `PYTHONIOENCODING=utf-8` in batch files as safety measure

**Examples**:
```python
# [FORBIDDEN] Will crash in enterprise Windows
print("✓ Success")  # Unicode checkmark - NEVER
print("❌ Failed")   # Unicode X - NEVER
print("⏳ Wait…")    # Unicode symbols - NEVER

# [REQUIRED] ASCII-only alternatives
print("[PASS] Success")
print("[FAIL] Failed")
print("[INFO] Wait...")
```

### Critical: Azure Account Management

**Multiple Azure Accounts Pattern**
- **Personal Account**: {PERSONAL_SUBSCRIPTION_NAME} ({PERSONAL_SUBSCRIPTION_ID}) - personal sandbox
- **Professional Account**: {PROFESSIONAL_EMAIL} - {ORGANIZATION} production access
- **{ORGANIZATION} Subscriptions** (require professional account):
  - {DEV_SUBSCRIPTION_NAME} ({DEV_SUBSCRIPTION_ID}) - Dev+Stage environments
  - {PROD_SUBSCRIPTION_NAME} ({PROD_SUBSCRIPTION_ID}) - Production environments

**When Azure CLI fails with "subscription doesn't exist"**:
1. Check current account: `az account show --query user.name`
2. Switch accounts: `az logout` then `az login --use-device-code --tenant {TENANT_ID}`
3. Authenticate with professional email: {PROFESSIONAL_EMAIL}
4. Verify access: `az account list --query "[?contains(id, '{DEV_SUBSCRIPTION_ID_PARTIAL}') || contains(id, '{PROD_SUBSCRIPTION_ID_PARTIAL}')]"`

**Pattern**: If accessing {ORGANIZATION} resources, ALWAYS use professional account

### AI Context Management Strategy

**Pattern**: Systematic approach to avoid context overload

**5-Step Process**:
1. **Assess**: What context do I need? (Don't load everything)
2. **Prioritize**: What's most relevant NOW? (Focus on current task)
3. **Load**: Get specific context only (Use targeted file reads, grep searches)
4. **Execute**: Perform task with loaded context
5. **Verify**: Validate result matches intent

**Example**:
```python
# [AVOID] Bad: Load entire file when only need one function
with open('large_file.py') as f:
    content = f.read()  # Loads 10,000 lines

# [RECOMMENDED] Good: Targeted context loading
grep_search(query="def target_function", includePattern="large_file.py")
read_file(filePath="large_file.py", startLine=450, endLine=500)
```

**When to re-assess context**:
- Task scope changes
- Error requires different context
- User provides new information

### Azure Services & Capabilities Inventory

**Azure OpenAI**
- **Models**: GPT-4, GPT-4 Turbo, text-embedding-ada-002
- **Endpoints**: {AZURE_OPENAI_ENDPOINT}
- **Use Cases**: Chat completions, embeddings, content generation
- **Authentication**: API key or DefaultAzureCredential

**Azure AI Services (Cognitive Services)**
- **Capabilities**: Query optimization, content safety, content understanding
- **Use Cases**: Text analysis, translation, content moderation
- **Pattern**: Always implement fallback for private endpoint failures

**Azure Cognitive Search**
- **Capabilities**: Hybrid search (vector + keyword), semantic ranking
- **Use Cases**: Document search, RAG systems, knowledge bases
- **Pattern**: Use index-based access, implement retry logic

**Azure Cosmos DB**
- **Capabilities**: NoSQL database, session storage, change feed
- **Use Cases**: Session management, audit logs, CDC patterns
- **Pattern**: Use partition keys effectively, implement TTL

**Azure Blob Storage**
- **Capabilities**: Object storage, containers, metadata
- **Use Cases**: Document storage, file uploads, static assets
- **Pattern**: Use managed identity, implement lifecycle policies

**Azure Functions**
- **Capabilities**: Serverless compute, event-driven processing
- **Use Cases**: Document pipelines, webhook handlers, scheduled jobs
- **Pattern**: Use blob triggers, queue bindings

**Azure Document Intelligence**
- **Capabilities**: OCR, form recognition, layout analysis
- **Use Cases**: PDF processing, document extraction
- **Pattern**: Handle rate limits, implement retry logic

### Professional Component Architecture

**Pattern**: Enterprise-grade component design (from Project 06/07)

**Every professional component implements**:
- **DebugArtifactCollector**: Evidence at operation boundaries
- **SessionManager**: Checkpoint/resume capabilities
- **StructuredErrorHandler**: JSON logging with context
- **Observability Wrapper**: Pre-state, execution, post-state capture

**Usage Pattern - Combining Components**:

> **Note**: The following shows a conceptual pattern for combining components. For complete, production-ready implementations you can copy-paste directly, see the detailed sections below.
```python
from pathlib import Path
from datetime import datetime
import json

class ProfessionalComponent:
    """Base class for enterprise-grade components"""
    
    def __init__(self, component_name: str, base_path: Path):
        self.component_name = component_name
        self.base_path = base_path
        
        # Core professional infrastructure
        self.debug_collector = DebugArtifactCollector(component_name, base_path)
        self.session_manager = SessionManager(component_name, base_path)
        self.error_handler = StructuredErrorHandler(component_name, base_path)
    
    async def execute_with_observability(self, operation_name: str, operation):
        """Execute operation with full evidence collection"""
        # 1. ALWAYS capture pre-state
        await self.debug_collector.capture_state(f"{operation_name}_before")
        await self.session_manager.save_checkpoint("before_operation", {
            "operation": operation_name,
            "timestamp": datetime.now().isoformat()
        })
        
        try:
            # 2. Execute operation
            result = await operation()
            
            # 3. ALWAYS capture success state
            await self.debug_collector.capture_state(f"{operation_name}_success")
            await self.session_manager.save_checkpoint("operation_success", {
                "operation": operation_name,
                "result_preview": str(result)[:200]
            })
            return result
            
        except Exception as e:
            # 4. ALWAYS capture error state
            await self.debug_collector.capture_state(f"{operation_name}_error")
            await self.error_handler.log_structured_error(operation_name, e)
            raise
```

**When to use**: Any component that interacts with external systems, complex logic, or enterprise automation

---

### Implementation: DebugArtifactCollector

**Purpose**: Capture comprehensive diagnostic state at system boundaries for rapid debugging

**Working Implementation** (from Project 06):
```python
from pathlib import Path
from datetime import datetime
import json
import asyncio

class DebugArtifactCollector:
    """Systematic evidence capture at operation boundaries
    
    Captures HTML, screenshots, network traces, and structured logs
    for every significant operation to enable rapid debugging.
    """
    
    def __init__(self, component_name: str, base_path: Path):
        """Initialize collector for specific component
        
        Args:
            component_name: Name of component (e.g., "authentication", "data_extraction")
            base_path: Project root directory
        """
        self.component_name = component_name
        self.debug_dir = base_path / "debug" / component_name
        self.debug_dir.mkdir(parents=True, exist_ok=True)
        
        self.page = None  # Set by browser automation
        self.network_log = []  # Populated by network listener
    
    async def capture_state(self, context: str):
        """Capture complete diagnostic state
        
        Args:
            context: Operation context (e.g., "before_login", "after_submit", "error_state")
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 1. Capture HTML snapshot
        if self.page:
            html_file = self.debug_dir / f"{context}_{timestamp}.html"
            html_content = await self.page.content()
            html_file.write_text(html_content, encoding='utf-8')
        
        # 2. Capture screenshot
        if self.page:
            screenshot_file = self.debug_dir / f"{context}_{timestamp}.png"
            await self.page.screenshot(path=str(screenshot_file), full_page=True)
        
        # 3. Capture network trace
        if self.network_log:
            network_file = self.debug_dir / f"{context}_{timestamp}_network.json"
            network_file.write_text(json.dumps(self.network_log, indent=2))
        
        # 4. Capture structured log with application state
        log_file = self.debug_dir / f"{context}_{timestamp}.json"
        log_file.write_text(json.dumps({
            "timestamp": timestamp,
            "context": context,
            "component": self.component_name,
            "url": self.page.url if self.page else None,
            "viewport": await self.page.viewport_size() if self.page else None
        }, indent=2))
        
        return {
            "html": str(html_file) if self.page else None,
            "screenshot": str(screenshot_file) if self.page else None,
            "network": str(network_file) if self.network_log else None,
            "log": str(log_file)
        }
    
    def set_page(self, page):
        """Attach to browser page for capture"""
        self.page = page
        
        # Enable network logging
        async def log_request(request):
            self.network_log.append({
                "timestamp": datetime.now().isoformat(),
                "type": "request",
                "url": request.url,
                "method": request.method
            })
        
        page.on("request", lambda req: asyncio.create_task(log_request(req)))
```

**Usage Pattern**:
```python
# In your automation component
collector = DebugArtifactCollector("my_component", project_root)
collector.set_page(page)

# Before risky operation
await collector.capture_state("before_submit")

try:
    await risky_operation()
    await collector.capture_state("success")
except Exception as e:
    await collector.capture_state("error")
    raise
```

---

### Implementation: SessionManager

**Purpose**: Enable checkpoint/resume capabilities for long-running operations

**Working Implementation** (from Project 06):
```python
from pathlib import Path
from datetime import datetime, timedelta
import json
import shutil
from typing import Dict, Optional

class SessionManager:
    """Manages persistent session state for checkpoint/resume operations
    
    Enables long-running automation to save progress and resume
    from last successful checkpoint if interrupted.
    """
    
    def __init__(self, component_name: str, base_path: Path):
        """Initialize session manager
        
        Args:
            component_name: Component identifier
            base_path: Project root directory
        """
        self.component_name = component_name
        self.session_dir = base_path / "sessions" / component_name
        self.session_dir.mkdir(parents=True, exist_ok=True)
        
        self.session_file = self.session_dir / "session_state.json"
        self.checkpoint_dir = self.session_dir / "checkpoints"
        self.checkpoint_dir.mkdir(exist_ok=True)
    
    def save_checkpoint(self, checkpoint_id: str, data: Dict) -> Path:
        """Save checkpoint with state data
        
        Args:
            checkpoint_id: Unique checkpoint identifier (e.g., "item_5_processed")
            data: State data to persist
            
        Returns:
            Path to saved checkpoint file
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        checkpoint_file = self.checkpoint_dir / f"{checkpoint_id}_{timestamp}.json"
        
        checkpoint_data = {
            "checkpoint_id": checkpoint_id,
            "timestamp": datetime.now().isoformat(),
            "component": self.component_name,
            "data": data
        }
        
        checkpoint_file.write_text(json.dumps(checkpoint_data, indent=2))
        
        # Update session state to point to latest checkpoint
        self.update_session_state(checkpoint_id, str(checkpoint_file))
        
        return checkpoint_file
    
    def load_latest_checkpoint(self) -> Optional[Dict]:
        """Load most recent checkpoint if available
        
        Returns:
            Checkpoint data or None if no checkpoint exists
        """
        if not self.session_file.exists():
            return None
        
        try:
            session_data = json.loads(self.session_file.read_text())
            checkpoint_file = Path(session_data.get("latest_checkpoint"))
            
            if checkpoint_file.exists():
                return json.loads(checkpoint_file.read_text())
            
        except Exception as e:
            print(f"[WARN] Failed to load checkpoint: {e}")
        
        return None
    
    def update_session_state(self, checkpoint_id: str, checkpoint_path: str):
        """Update session state with latest checkpoint reference"""
        session_data = {
            "component": self.component_name,
            "last_updated": datetime.now().isoformat(),
            "latest_checkpoint": checkpoint_path,
            "checkpoint_id": checkpoint_id
        }
        
        self.session_file.write_text(json.dumps(session_data, indent=2))
    
    def clear_session(self):
        """Clear all session state and checkpoints"""
        if self.checkpoint_dir.exists():
            shutil.rmtree(self.checkpoint_dir)
            self.checkpoint_dir.mkdir()
        
        if self.session_file.exists():
            self.session_file.unlink()
```

**Usage Pattern**:
```python
# Initialize session manager
session_mgr = SessionManager("batch_processor", project_root)

# Try to resume from checkpoint
checkpoint = session_mgr.load_latest_checkpoint()
if checkpoint:
    start_index = checkpoint["data"]["last_processed_index"]
    print(f"[INFO] Resuming from checkpoint: item {start_index}")
else:
    start_index = 0

# Process items with checkpoints
for i in range(start_index, len(items)):
    process_item(items[i])
    
    # Save checkpoint every 10 items
    if i % 10 == 0:
        session_mgr.save_checkpoint(f"item_{i}", {
            "last_processed_index": i,
            "items_completed": i + 1,
            "timestamp": datetime.now().isoformat()
        })
```

---

### Implementation: StructuredErrorHandler

**Purpose**: Provide JSON-based error logging with full context for debugging

**Working Implementation** (from Project 06):
```python
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path
import json
import traceback

class StructuredErrorHandler:
    """Enterprise-grade error handling with structured logging
    
    Captures errors with full context in JSON format for easy parsing
    and analysis. All output is ASCII-safe for enterprise Windows.
    """
    
    def __init__(self, component_name: str, base_path: Path):
        """Initialize error handler
        
        Args:
            component_name: Component identifier
            base_path: Project root directory
        """
        self.component_name = component_name
        self.error_dir = base_path / "logs" / "errors"
        self.error_dir.mkdir(parents=True, exist_ok=True)
    
    def log_error(self, error: Exception, context: Optional[Dict[str, Any]] = None) -> Dict:
        """Log error with structured context
        
        Args:
            error: Exception object
            context: Additional context (operation name, parameters, etc.)
            
        Returns:
            Error report dictionary
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        error_report = {
            "timestamp": datetime.now().isoformat(),
            "component": self.component_name,
            "error_type": type(error).__name__,
            "error_message": str(error),
            "traceback": traceback.format_exc(),
            "context": context or {}
        }
        
        # Save to timestamped file
        error_file = self.error_dir / f"{self.component_name}_error_{timestamp}.json"
        error_file.write_text(json.dumps(error_report, indent=2))
        
        # Print ASCII-safe error message
        print(f"[ERROR] {self.component_name}: {type(error).__name__}")
        print(f"[ERROR] Message: {str(error)}")
        print(f"[ERROR] Details saved to: {error_file}")
        
        return error_report
    
    def log_structured_event(self, event_type: str, data: Dict[str, Any]):
        """Log structured event (non-error)
        
        Args:
            event_type: Event type (e.g., "operation_start", "data_validated")
            data: Event data
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        event_report = {
            "timestamp": datetime.now().isoformat(),
            "component": self.component_name,
            "event_type": event_type,
            "data": data
        }
        
        # Save to events log
        event_file = self.error_dir.parent / f"{self.component_name}_events_{timestamp}.json"
        event_file.write_text(json.dumps(event_report, indent=2))

class ProjectBaseException(Exception):
    """Base exception with structured error reporting
    
    All custom exceptions should inherit from this to ensure
    consistent error handling and reporting.
    """
    
    def __init__(self, message: str, context: Optional[Dict[str, Any]] = None):
        """Initialize exception with context
        
        Args:
            message: Error description (ASCII only)
            context: Additional error context
        """
        super().__init__(message)
        self.message = message
        self.context = context or {}
        self.timestamp = datetime.now().isoformat()
    
    def get_error_report(self) -> Dict[str, Any]:
        """Generate structured error report
        
        Returns:
            Dictionary with full error details
        """
        return {
            "error_type": self.__class__.__name__,
            "message": self.message,
            "context": self.context,
            "timestamp": self.timestamp
        }
```

**Usage Pattern**:
```python
# Initialize error handler
error_handler = StructuredErrorHandler("my_automation", project_root)

try:
    risky_operation()
except Exception as e:
    # Log with context
    error_handler.log_error(e, context={
        "operation": "data_processing",
        "input_file": "data.csv",
        "current_row": 42
    })
    raise

# Custom exception with automatic context
class DataValidationError(ProjectBaseException):
    pass

try:
    if not is_valid(data):
        raise DataValidationError(
            "Invalid data format",
            context={"expected": "CSV", "received": "JSON"}
        )
except DataValidationError as e:
    error_report = e.get_error_report()
    error_handler.log_error(e, context=error_report["context"])
```

---

### Implementation: Zero-Setup Project Runner

**Purpose**: Enable users to run project from anywhere without configuration

**Working Implementation** (from Project 06):
```python
#!/usr/bin/env python3
"""Professional project runner with zero-setup execution"""

import os
import sys
import argparse
from pathlib import Path
import subprocess
from typing import List

# Set UTF-8 encoding for Windows
os.environ.setdefault('PYTHONIOENCODING', 'utf-8')

class ProfessionalRunner:
    """Zero-setup professional automation wrapper"""
    
    def __init__(self):
        self.project_root = self.auto_detect_project_root()
        self.main_script = "scripts/main_automation.py"
    
    def auto_detect_project_root(self) -> Path:
        """Find project root from any subdirectory
        
        Searches for project markers in current and parent directories
        to enable running from any location within the project.
        """
        current = Path.cwd()
        
        # Project indicators (customize for your project)
        indicators = [
            "scripts/main_automation.py",
            "ACCEPTANCE.md",
            "README.md",
            ".git"
        ]
        
        # Check current directory
        for indicator in indicators:
            if (current / indicator).exists():
                return current
        
        # Check parent directories
        for parent in current.parents:
            for indicator in indicators:
                if (parent / indicator).exists():
                    return parent
        
        # Fallback to current directory
        print("[WARN] Could not auto-detect project root, using current directory")
        return current
    
    def validate_pre_flight(self) -> tuple[bool, str]:
        """Pre-flight checks before execution
        
        Validates environment, dependencies, and project structure.
        
        Returns:
            (success: bool, message: str)
        """
        checks = []
        
        # Check main script exists
        main_script_path = self.project_root / self.main_script
        if not main_script_path.exists():
            return False, f"[FAIL] Main script not found: {main_script_path}"
        checks.append("[PASS] Main script found")
        
        # Check required directories
        required_dirs = ["input", "output", "logs"]
        for dir_name in required_dirs:
            dir_path = self.project_root / dir_name
            if not dir_path.exists():
                dir_path.mkdir(parents=True)
                checks.append(f"[INFO] Created directory: {dir_name}")
            else:
                checks.append(f"[PASS] Directory exists: {dir_name}")
        
        # Check Python dependencies
        try:
            import pandas
            import asyncio
            checks.append("[PASS] Required Python modules available")
        except ImportError as e:
            return False, f"[FAIL] Missing Python module: {e}"
        
        return True, "\n".join(checks)
    
    def build_command(self, **kwargs) -> List[str]:
        """Build command with normalized parameters
        
        Converts user inputs to proper command structure.
        """
        cmd = [
            sys.executable,
            str(self.project_root / self.main_script)
        ]
        
        # Add parameters (customize for your project)
        for key, value in kwargs.items():
            if value is not None:
                if isinstance(value, bool):
                    if value:
                        cmd.append(f"--{key}")
                else:
                    cmd.extend([f"--{key}", str(value)])
        
        return cmd
    
    def execute_with_enterprise_safety(self, cmd: List[str]) -> int:
        """Execute with proper encoding and error handling"""
        # Set environment
        env = os.environ.copy()
        env['PYTHONIOENCODING'] = 'utf-8'
        
        # Change to project root
        original_cwd = os.getcwd()
        os.chdir(self.project_root)
        
        try:
            print(f"[INFO] Project root: {self.project_root}")
            print(f"[INFO] Command: {' '.join(cmd)}")
            print("-" * 60)
            
            result = subprocess.run(cmd, env=env)
            return result.returncode
            
        finally:
            os.chdir(original_cwd)
    
    def run(self, **kwargs) -> int:
        """Main execution entry point"""
        print("[INFO] Professional Runner - Zero-Setup Execution")
        print(f"[INFO] Detected project root: {self.project_root}")
        
        # Pre-flight validation
        success, message = self.validate_pre_flight()
        print("\n" + message)
        
        if not success:
            print("\n[FAIL] Pre-flight checks failed")
            return 1
        
        # Build and execute command
        cmd = self.build_command(**kwargs)
        return self.execute_with_enterprise_safety(cmd)

def main():
    """CLI entry point"""
    parser = argparse.ArgumentParser(
        description="Professional automation runner with zero-setup execution"
    )
    
    # Add your project-specific arguments here
    parser.add_argument("--input", help="Input file path")
    parser.add_argument("--output", help="Output file path")
    parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    
    args = parser.parse_args()
    
    # Create runner and execute
    runner = ProfessionalRunner()
    sys.exit(runner.run(**vars(args)))

if __name__ == "__main__":
    main()
```

**Usage**:
```bash
# Run from anywhere in the project
python run_project.py --input data.csv --output results.csv

# Or create Windows batch wrapper
# run_project.bat:
@echo off
set PYTHONIOENCODING=utf-8
python run_project.py %*
```

---

### Professional Transformation Methodology

**Pattern**: Systematic 4-step approach to enterprise-grade development

**When refactoring or creating automation systems**:

1. **Foundation Systems** (20% of work)
   - Create `debug/`, `evidence/`, `logs/` directory structure
   - Establish coding standards and utilities
   - Implement ASCII-only error handling
   - Set up structured logging infrastructure

2. **Testing Framework** (30% of work)
   - Automated validation with evidence collection
   - Component-level unit tests
   - Integration tests with retry logic
   - Acceptance criteria validation

3. **Main System Refactoring** (40% of work)
   - Apply professional component architecture
   - Integrate validation and observability
   - Implement graceful error handling
   - Add session management and checkpoints

4. **Documentation & Cleanup** (10% of work)
   - Consolidate redundant code
   - Document patterns and decisions
   - Create runbooks and troubleshooting guides
   - Archive superseded implementations

**Quality Gate**: Each phase produces evidence before proceeding to next phase

### Dependency Management with Alternatives

**Pattern**: Handle blocked packages in enterprise environments

**PRIMARY SOLUTION: Offline Package Download** (ESDC Standard)

**Problem**: ESDC internal pip repository lacks many packages  
**Solution**: Download from public PyPI on elevated machine, install offline in restricted environment

**Quick Commands**:
```powershell
# On elevated account/DevBox (one-time)
cd scripts
.\Download-Offline-Packages.ps1

# On restricted workstation (repeatable)
cd offline-packages
.\Install-Offline.ps1

# Verify installation
python -c "import package_name; print('[PASS] Package working')"
```

**Comprehensive Guide**: See [Python Dependency Management](../../best-practices/PYTHON-DEPENDENCY-MANAGEMENT.md)

**FALLBACK: Code-Level Alternatives**:

```python
# Pattern 1: Try primary, fall back to alternative
try:
    from playwright.async_api import async_playwright
    BROWSER_ENGINE = "playwright"
except ImportError:
    print("[INFO] Playwright not available, using Selenium")
    from selenium import webdriver
    BROWSER_ENGINE = "selenium"

# Pattern 2: Feature detection
def get_available_http_client():
    """Return best available HTTP client"""
    if importlib.util.find_spec("httpx"):
        import httpx
        return httpx.AsyncClient()
    elif importlib.util.find_spec("aiohttp"):
        import aiohttp
        return aiohttp.ClientSession()
    else:
        import urllib.request
        return urllib.request  # Fallback to stdlib

# Pattern 3: Document alternatives in requirements
# requirements.txt:
# playwright>=1.40.0  # Primary choice
# selenium>=4.15.0    # Alternative if playwright blocked
# requests>=2.31.0    # Fallback for basic HTTP
```

**Document why alternatives chosen**: Add comments explaining enterprise constraints

**Virtual Environment Best Practice**: One .venv per project root (not per subproject)
```
project-root/
├── .venv/                    # ✅ Single venv at root
├── scripts/
│   └── Download-Offline-Packages.ps1
└── offline-packages/         # ✅ Portable package cache
    ├── *.whl
    ├── Install-Offline.ps1
    └── INSTALLATION-INSTRUCTIONS.txt
```

### Workspace Housekeeping Principles

**Context Engineering - Keep AI context clean and focused**

**Best Practices**:
- **Root directory**: Active operations only (`RESTART_SERVERS.ps1`, `README.md`)
- **Context folder**: Use `docs/eva-foundation/` as AI agent "brain"
  - `projects/` - Active work with debugging artifacts
  - `workspace-notes/` - Ephemeral notes, workflow docs
  - `system-analysis/` - Architecture docs, inventory reports
  - `comparison-reports/` - Automated comparison outputs
  - `automation/` - Code generation scripts

**Pattern**: If referenced in copilot-instructions.md or used for AI context → belongs in `docs/eva-foundation/`

**File Organization Rules**:
1. **Logs** → `logs/{category}/`
   - `logs/deployment/terraform/` - Terraform logs
   - `logs/deployment/` - Deployment logs
   - `logs/tests/` - Test output

2. **Scripts** → `scripts/{category}/`
   - `scripts/deployment/` - Deploy, build, infrastructure
   - `scripts/testing/` - Test runners, evidence capture
   - `scripts/setup/` - Installation, configuration
   - `scripts/diagnostics/` - Health checks, validation
   - `scripts/housekeeping/` - Workspace organization

3. **Documentation** → `docs/{category}/`
   - Implementation docs → `docs/eva-foundation/projects/{project-name}/`
   - Deployment guides → `docs/deployment/`
   - Debug sessions → `docs/eva-foundation/projects/{session-name}-debug/`

**Naming Conventions**:
- **Scripts**: `verb-noun.ps1` (lowercase-with-dashes)
  - [RECOMMENDED] Good: `deploy-infrastructure.ps1`, `test-environment.ps1`
  - [AVOID] Bad: `Deploy-MSInfo-Fixed.ps1`, `TEST_COMPLETE.ps1`
- **Docs**: `CATEGORY-DESCRIPTION.md` (UPPERCASE for status docs)
  - [RECOMMENDED] Good: `DEPLOYMENT-STATUS.md`, `IMPLEMENTATION-SUMMARY.md`
  - [AVOID] Bad: `Final-Status-Report.ps1.md`
- **Logs**: `{operation}-{timestamp}.log` or `{component}.log`

**Self-Organizing Rules for AI Agents**:
- **Before creating a file**: Check if similar file exists in `docs/eva-foundation/`
- **When debugging**: Create session folder `docs/eva-foundation/projects/{issue-name}-debug/`
- **After completing work**: Summarize findings in `docs/eva-foundation/workspace-notes/`
- **When context grows**: Create comparison report, archive superseded versions

**Housekeeping Automation**:
```powershell
# Daily cleanup
.\scripts\housekeeping\organize-workspace.ps1

# Weekly archival
.\scripts\housekeeping\archive-debug-sessions.ps1
```

### Evidence Collection at Operation Boundaries

**Goal**: Systematic evidence capture for rapid debugging

**MANDATORY: Every component operation must capture**:
- **Pre-state**: HTML, screenshots, network traces BEFORE execution
- **Success state**: Evidence on successful completion  
- **Error state**: Full diagnostic artifacts on failure
- **Structured logging**: JSON-based error context with timestamps

**Implementation Pattern**:
```python
class DebugArtifactCollector:
    def __init__(self, component_name: str, base_path: Path):
        self.component_name = component_name
        self.debug_dir = base_path / "debug" / component_name
        self.debug_dir.mkdir(parents=True, exist_ok=True)
    
    async def capture_state(self, context: str):
        """Capture complete diagnostic state"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Capture HTML snapshot
        if self.page:  # Browser automation
            html_file = self.debug_dir / f"{context}_{timestamp}.html"
            await self.page.content().write(html_file)
        
        # Capture screenshot
        if self.page:
            screenshot_file = self.debug_dir / f"{context}_{timestamp}.png"
            await self.page.screenshot(path=screenshot_file)
        
        # Capture network trace
        if self.network_log:
            network_file = self.debug_dir / f"{context}_{timestamp}_network.json"
            network_file.write_text(json.dumps(self.network_log, indent=2))
        
        # Capture structured log
        log_file = self.debug_dir / f"{context}_{timestamp}.json"
        log_file.write_text(json.dumps({
            "timestamp": timestamp,
            "context": context,
            "component": self.component_name,
            "url": str(self.page.url) if self.page else None,
            "state": await self._capture_application_state()
        }, indent=2))
```

**Timestamped Naming Convention (MANDATORY)**:
- Pattern: `{component}_{context}_{YYYYMMDD_HHMMSS}.{ext}`
- Examples:
  - `{component}_debug_error_attempt_1_{YYYYMMDD_HHMMSS}.html`
  - `automation_execution_{YYYYMMDD_HHMMSS}.log`
  - `results_batch_001_{YYYYMMDD_HHMMSS}.csv`
- Benefits: Chronological sorting, parallel execution support, audit trails

**Azure Configuration State Tracking**:

**Structure**:
```
docs/eva-foundation/system-analysis/inventory/.eva-cache/
  azure-connectivity-{subscription}-{timestamp}.md
  azure-permissions-{subscription}-{timestamp}.md
  evidence-{subscription}-{timestamp}.md
  canonical-analysis/{storage-account}-{timestamp}.md
```

**Usage Pattern**:
1. Capture current state: `evidence-{subscription}-{timestamp}.md`
2. Compare with previous state: `evidence-{subscription}-{earlier-timestamp}.md`
3. Generate comparison report: `comparison-report-{timestamp}.md`
4. Document findings in project debug folder

### Code Style Standards

**Python**:
- **Type Hints**: Use for all function signatures
- **Async/Await**: Use throughout for I/O operations
- **Naming**: `snake_case` functions/variables, `PascalCase` classes
- **Formatting**: Black (line length 180) + isort
- **Error Handling**: Wrap external calls with try/except, respect `OPTIONAL` flags

**TypeScript**:
- **Naming**: `camelCase` functions/variables, `PascalCase` components/types
- **Components**: Functional components with hooks
- **State**: React Context for global state
- **Styling**: CSS Modules + component libraries

**Files**:
- Python: `snake_case.py`
- TypeScript: `lowercase-with-dashes.tsx`

---

**You are now ready for project-specific patterns**  
See [PART 2: {PROJECT_NAME} Project Specific](#part-2-project-name-project-specific) below for AI-instructional project patterns.

---



## PART 2: 14-az-finops PROJECT SPECIFIC

> **Azure FinOps Automation System**  
> FinOps cost management patterns for Azure subscription optimization

### Documentation Guide

**Primary References**:
- **This file** (copilot-instructions.md): Quick reference workflows and patterns
- **[README.md](../README.md)**: Complete project overview, status, acceptance criteria
- **[WHEN-TO-USE-WHAT.md](../WHEN-TO-USE-WHAT.md)**: Decision matrix for SDK vs FinOps Hub

### Architecture Overview

**System Type**: Azure FinOps Automation - Multi-phase cost management system

**Strategic Approach**:
- **Development Environment**: MarcoSub (c59ee575-eb2a-4b51-a865-4b618f9add0a) - $50-100/month personal sandbox
- **Production Target**: EsDAICoESub (d2d4e571-e0f2-4f6c-901a-f88f7669bcba) - $23,000+/month production workloads
- **Pattern**: Validate complete FinOps workflow in MarcoSub, then replicate to EsDAICoESub production

**Core Components**:
1. **Azure SDK Scripts** (`scripts/`) - Fast cost extraction and inventory (1-minute runtime)
2. **FinOps Hub** (Microsoft Toolkit) - Enterprise-grade Power BI dashboards and automation
3. **Data Pipeline** - Seed data (11 months) + daily automated exports
4. **Storage Architecture** - Azure Blob Storage with FOCUS data specification

**Technology Stack**: 
- Python 3.x (Azure SDK)
- PowerShell (deployment automation)
- Azure Cost Management API
- Azure Data Factory (FinOps Hub pipeline)
- Power BI Desktop (dashboards)
- Microsoft FinOpsToolkit

**Critical Architecture Patterns**:
- **Seed + Daily Pattern**: One-time historical bulk load + automated daily increments
- **Multi-Subscription Management**: Same patterns across dev (MarcoSub) and prod (EsDAICoESub)
- **Graceful Region Flexibility**: Dev uses eastus2, prod will use canadacentral/canadaeast
- **Data Normalization**: FOCUS (FinOps Open Cost & Usage Specification) standard

### Project Structure

```
14-az-finops/
├── scripts/
│   ├── extract_costs_sdk.py       # Azure SDK cost extraction (267 lines, <1 min)
│   ├── azure_inventory.py         # Resource inventory + tag compliance (214 lines)
│   ├── Deploy-FinOpsHub.ps1       # Microsoft FinOpsToolkit deployment
│   ├── Validate-Prerequisites.ps1 # Pre-flight environment validation
│   └── test_setup.py              # Dependency testing
├── portal-exports/
│   ├── api-extracted/             # SDK output (CSV + JSON)
│   └── inventory/                 # Resource inventory data
├── archive/
│   └── v1-manual-approach/        # Legacy 883-line PowerShell scripts (superseded)
├── README.md                      # Project status and quick start (402 lines)
├── requirements.txt               # Python dependencies (Azure SDK)
├── WHEN-TO-USE-WHAT.md           # Tool selection decision matrix
├── DEPLOYMENT-SUCCESS-20260129.md # FinOps Hub deployment evidence
└── PERMISSION-BLOCKER-20260129.md # EsDAICoESub credential escalation tracker
```

### Development Workflows

**Multi-Subscription Pattern**:

```powershell
# ALWAYS authenticate to ESDC tenant first
az login --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8

# FOR DEVELOPMENT: Set context to MarcoSub
az account set --subscription c59ee575-eb2a-4b51-a865-4b618f9add0a

# FOR PRODUCTION (when credentials available): Set context to EsDAICoESub
az account set --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba

# Verify current context
az account show --query "{Name:name, SubscriptionId:id, User:user.name, Tenant:tenantId}"
```

**Local Development Setup**:

```powershell
# 1. Install Python dependencies
cd I:\EVA-JP-v1.2\docs\eva-foundation\projects\14-az-finops
pip install -r requirements.txt

# 2. Verify Azure CLI authentication
az login --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8

# 3. Set subscription context (MarcoSub for dev)
az account set --subscription c59ee575-eb2a-4b51-a865-4b618f9add0a

# 4. Validate environment
.\scripts\Validate-Prerequisites.ps1
```

**Quick Commands**:

```powershell
# Ad-hoc cost extraction (1-minute turnaround)
python scripts/extract_costs_sdk.py

# Extract specific date range
python scripts/extract_costs_sdk.py --start-date 2025-02-01 --end-date 2025-12-31

# Resource inventory with tag compliance
python scripts/azure_inventory.py

# Validate FinOps Hub deployment (check 10 resources)
.\scripts\Validate-Prerequisites.ps1

# Deploy FinOps Hub to MarcoSub (first-time setup)
.\scripts\Deploy-FinOpsHub.ps1 -Subscription "MarcoSub" -Location "eastus2"

# Check Data Factory pipeline status
az datafactory pipeline-run query-by-factory `
  --factory-name eva-finops-hub-engine-eodbqqq6g72kc `
  --resource-group eva-finops-rg `
  --last-updated-after "2026-01-29T00:00:00Z" `
  --output table
```

### Critical Code Patterns

#### Pattern 1: Azure SDK Cost Extraction with Date Range

**Purpose**: Extract cost data programmatically without manual portal exports (95% faster than manual)

**Implementation** (`scripts/extract_costs_sdk.py`):
```python
from azure.identity import DefaultAzureCredential
from azure.mgmt.costmanagement import CostManagementClient
from datetime import datetime, timedelta

# CRITICAL: Use DefaultAzureCredential (supports CLI, managed identity, service principal)
credential = DefaultAzureCredential()

# Initialize Cost Management client
client = CostManagementClient(credential)

# Define scope (subscription level)
scope = f"/subscriptions/{subscription_id}"

# Query definition
query_definition = {
    "type": "ActualCost",
    "timeframe": "Custom",
    "timePeriod": {
        "from": "2025-02-01T00:00:00Z",  # Start date
        "to": "2025-12-31T23:59:59Z"     # End date
    },
    "dataset": {
        "granularity": "Daily",
        "aggregation": {
            "totalCost": {
                "name": "PreTaxCost",
                "function": "Sum"
            }
        },
        "grouping": [
            {"type": "Dimension", "name": "ResourceGroupName"},
            {"type": "Dimension", "name": "ResourceType"},
            {"type": "Dimension", "name": "MeterCategory"},
            {"type": "Dimension", "name": "MeterSubCategory"}
        ]
    }
}

# Execute query (1-2 minutes for 11 months of data)
result = client.query.usage(scope, query_definition)

# Process results to CSV
import pandas as pd

rows = []
for row in result.rows:
    rows.append({
        "Date": row[0],
        "PreTaxCost": row[1],
        "ResourceGroup": row[2],
        "ResourceType": row[3],
        "MeterCategory": row[4],
        "MeterSubCategory": row[5],
        "Currency": row[6]
    })

df = pd.DataFrame(rows)
df.to_csv("portal-exports/api-extracted/costs_YYYYMMDD.csv", index=False)
```

**Key Benefits**:
- 64% code reduction (1,321 lines → 481 lines)
- 95% time savings (12-19 minutes → 1 minute)
- Zero manual portal interaction
- Programmatic date range selection

#### Pattern 2: Seed + Daily Data Loading Strategy

**Purpose**: Combine one-time historical bulk load with ongoing daily automation

**Implementation Pattern**:

```powershell
# PHASE 1: Seed Historical Data (One-Time)
# Load 11 months of MarcoSub historical data
python scripts/extract_costs_sdk.py --start-date 2025-02-01 --end-date 2025-12-31
# Output: portal-exports/api-extracted/costs_20260130_seed.csv

# PHASE 2: Configure Daily Exports (Automated)
az costmanagement export create `
  --name "FinOpsExport-MarcoSub-Daily" `
  --type "ActualCost" `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a" `
  --storage-account-id "/subscriptions/.../storageAccounts/evafinopshueodbqqq6g72kc" `
  --storage-container "msexports" `
  --storage-directory "MarcoSub" `
  --timeframe "MonthToDate" `
  --recurrence "Daily" `
  --recurrence-period from="2026-01-01" to="2026-12-31" `
  --format "Csv"

# Trigger first export immediately (Jan 1-30, 2026)
az costmanagement export execute `
  --name "FinOpsExport-MarcoSub-Daily" `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a"
```

**Data Coverage**:
- Seed Data (SDK): Feb 1, 2025 → Dec 31, 2025 (~11 months, one-time bulk)
- Daily Export: Jan 1, 2026 → ongoing (automated daily updates)
- Total: ~13 months continuous MarcoSub data

**Storage Structure**:
```
evafinopshueodbqqq6g72kc/
├── msexports/
│   └── MarcoSub/                    # Daily exports
│       ├── 20260130/ActualCost_*.csv
│       └── 20260131/ActualCost_*.csv
├── ingestion/
│   ├── FocusCost/                   # FOCUS normalized data
│   │   ├── year=2026/month=01/*.parquet
│   │   └── year=2025/month=02-12/*.parquet
│   └── Costs/                       # Merged seed + daily
└── seed-data/                       # Historical bulk load archive
    └── costs_20260130_seed.csv
```

#### Pattern 3: Multi-Subscription Management (Dev → Prod Replication)

⚠️ **DEPRECATED (2026-01-31):** Cross-tenant data transfer not supported. Current scope is **MarcoSub-only** development and validation.

**User Decision (2026-01-31):** "we are not doing daicoesub or paicoesub. that is old. i cannot transfer data across tenant. decision is to leave dev and prod costs in the backlog and do it all in marcosub"

**Historical Purpose:** Validate patterns in MarcoSub dev environment, then replicate to EsDAICoESub production

**Implementation (Historical Reference Only):**

```powershell
# DEVELOPMENT WORKFLOW (MarcoSub)
function Invoke-FinOpsWorkflow {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("MarcoSub", "EsDAICoESub")]
        [string]$Environment
    )
    
    # Environment-specific configuration
    $config = @{
        "MarcoSub" = @{
            SubscriptionId = "c59ee575-eb2a-4b51-a865-4b618f9add0a"
            Region = "eastus2"              # Dev: US region
            ResourceGroup = "eva-finops-rg"
            StorageAccount = "evafinopshueodbqqq6g72kc"
            DataFactory = "eva-finops-hub-engine-eodbqqq6g72kc"
            MonthlyCost = 50-100            # Low-cost development
        }
        "EsDAICoESub" = @{
            SubscriptionId = "d2d4e571-e0f2-4f6c-901a-f88f7669bcba"
            Region = "canadacentral"        # Prod: Canada region
            ResourceGroup = "eva-finops-prod-rg"
            StorageAccount = "evafinopsprod{random}"
            DataFactory = "eva-finops-prod-engine-{random}"
            MonthlyCost = 23000             # Production workloads
        }
    }
    
    $envConfig = $config[$Environment]
    
    # Set Azure context
    az account set --subscription $envConfig.SubscriptionId
    
    # Deploy FinOps Hub (same pattern, different environment)
    .\scripts\Deploy-FinOpsHub.ps1 `
        -Subscription $Environment `
        -Location $envConfig.Region `
        -ResourceGroup $envConfig.ResourceGroup
    
    # Configure cost export (same parameters, different scope)
    az costmanagement export create `
        --name "FinOpsExport-$Environment-Daily" `
        --scope "/subscriptions/$($envConfig.SubscriptionId)" `
        --storage-account-id "/.../storageAccounts/$($envConfig.StorageAccount)" `
        --recurrence "Daily"
}

# Use in development
Invoke-FinOpsWorkflow -Environment "MarcoSub"

# Replicate to production (when credentials available)
Invoke-FinOpsWorkflow -Environment "EsDAICoESub"
```

**Key Differences**:
| Aspect | MarcoSub (Dev) | EsDAICoESub (Prod) |
|--------|----------------|-------------------|
| Region | eastus2 (US) | canadacentral/canadaeast (Canada) |
| Cost | $50-100/month | $23,000+/month |
| Resources | ~20-30 | 1,179+ |
| Permissions | Owner | Reader + Cost Mgmt (needs Contributor) |
| Use Case | Pattern validation | Production optimization |

#### Pattern 4: FinOps Hub Deployment Validation

**Purpose**: Verify all deployed resources are operational (5 resources as of 2026-01-31)

**Implementation** (`scripts/Validate-Prerequisites.ps1`):

```powershell
# Query FinOps Hub resource group
$resources = az resource list -g eva-finops-rg --query "[].{Name:name, Type:type, Location:location}" -o json | ConvertFrom-Json

# Expected resources (verified 2026-01-31 16:18)
$expectedTypes = @(
    "Microsoft.Storage/storageAccounts",              # evafinopshueodbqqq6g72kc (1)
    "Microsoft.DataFactory/factories",                # eva-finops-hub-engine-eodbqqq6g72kc (1)
    "Microsoft.ManagedIdentity/userAssignedIdentities", # 2x (blob manager, trigger manager)
    "Microsoft.EventGrid/systemTopics"                # 1x (system topic)
)

# Validate deployment
$validationResults = @()
foreach ($type in $expectedTypes) {
    $found = $resources | Where-Object { $_.Type -eq $type }
    $validationResults += @{
        ResourceType = $type
        Expected = $true
        Found = $found.Count -gt 0
        Count = $found.Count
    }
}

# Report
$validationResults | Format-Table -AutoSize

# PASS/FAIL
$failures = $validationResults | Where-Object { -not $_.Found }
if ($failures.Count -eq 0) {
    Write-Host "[PASS] All 5 deployed resources operational" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Missing resources: $($failures.Count)" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $($_.ResourceType)" -ForegroundColor Yellow }
}
```

### Testing

**Test Strategy**:
- **Pre-flight Validation**: `Validate-Prerequisites.ps1` - Checks Azure CLI, subscriptions, permissions
- **Unit Tests**: `test_setup.py` - Validates Python dependencies and Azure SDK connectivity
- **Integration Tests**: Manual verification of Data Factory pipeline execution
- **End-to-End**: Compare SDK-extracted data vs FinOps Hub processed data for consistency

**Running Tests**:

```powershell
# Pre-flight validation (check environment)
.\scripts\Validate-Prerequisites.ps1

# Python dependency check
python scripts/test_setup.py

# Test SDK cost extraction (verify 1-minute runtime)
Measure-Command { python scripts/extract_costs_sdk.py --start-date 2026-01-01 --end-date 2026-01-31 }

# Test FinOps Hub pipeline execution
az datafactory pipeline-run query-by-factory `
  --factory-name eva-finops-hub-engine-eodbqqq6g72kc `
  --resource-group eva-finops-rg `
  --output table
```

### CI/CD Pipeline

**Current State**: Manual deployment and validation (no automated pipeline yet)

**Future Automation** (Planned):
```yaml
# .github/workflows/finops-deploy.yml
name: FinOps Hub Deployment

on:
  push:
    branches: [main]
    paths: ['scripts/Deploy-FinOpsHub.ps1', 'scripts/extract_costs_sdk.py']

jobs:
  validate-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_MARCOSUB }}
      
      - name: Set MarcoSub context
        run: az account set --subscription c59ee575-eb2a-4b51-a865-4b618f9add0a
      
      - name: Run pre-flight validation
        run: ./scripts/Validate-Prerequisites.ps1
      
      - name: Test SDK extraction
        run: python scripts/extract_costs_sdk.py --start-date 2026-01-01 --end-date 2026-01-31
  
  deploy-prod:
    needs: validate-dev
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS_ESDAICOE }}
      
      - name: Set EsDAICoESub context
        run: az account set --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba
      
      - name: Deploy FinOps Hub
        run: ./scripts/Deploy-FinOpsHub.ps1 -Environment "EsDAICoESub" -Location "canadacentral"
```

### Troubleshooting

#### Issue 1: "Subscription 'd2d4e571-...' doesn't exist" (EsDAICoESub Access)

**Symptom**: Azure CLI returns error when trying to set EsDAICoESub subscription context  
**Cause**: Currently authenticated with personal account (MarcoSub), not professional account  
**Solution**:
```powershell
# Logout from personal account
az logout

# Login with professional ESDC account
az login --use-device-code --tenant bfb12ca1-7f37-47d5-9cf5-8aa52214a0d8
# Authenticate as: marco.presta@hrsdc-rhdcc.gc.ca

# Verify EsDAICoESub access
az account list --query "[?contains(id, 'd2d4e571')]"

# Set context
az account set --subscription d2d4e571-e0f2-4f6c-901a-f88f7669bcba
```

#### Issue 2: FinOps Hub Deployment Shows 0 Resources

**Symptom**: `az resource list -g eva-finops-rg` returns empty array immediately after deployment  
**Cause**: Deployment script may still be running asynchronously, or deployment failed  
**Solution**:
```powershell
# Wait 5-10 minutes for deployment to complete
Start-Sleep -Seconds 300

# Re-check resource group
az resource list -g eva-finops-rg --query "[].{Name:name, Type:type}" -o table

# Check deployment logs
az deployment group show `
  --resource-group eva-finops-rg `
  --name "finops-hub-deployment" `
  --query "properties.{ProvisioningState:provisioningState, Timestamp:timestamp}"

# If failed, check deployment script logs
az deployment-scripts show-log `
  --resource-group eva-finops-rg `
  --name "deployment-script-helper"
```

#### Issue 3: Azure SDK Extraction Returns No Data

**Symptom**: `extract_costs_sdk.py` completes but generates empty CSV  
**Cause**: Insufficient Cost Management Reader permission, or date range before subscription creation  
**Solution**:
```powershell
# Verify Cost Management permissions
az role assignment list `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a" `
  --query "[?roleDefinitionName=='Cost Management Reader']"

# Check subscription creation date
az account show --query "{CreatedDate:createdTime, Name:name}"

# Adjust date range to after subscription creation
python scripts/extract_costs_sdk.py --start-date 2025-06-01 --end-date 2026-01-31
```

#### Issue 4: Power BI Can't Connect to Storage Account

**Symptom**: Power BI connector fails with "Access Denied" when connecting to evafinopshueodbqqq6g72kc  
**Cause**: Storage account behind private endpoint, or insufficient RBAC permissions  
**Solution**:
```powershell
# Verify storage account access
az storage blob list `
  --account-name evafinopshueodbqqq6g72kc `
  --container-name ingestion `
  --auth-mode login

# Grant Storage Blob Data Reader role
az role assignment create `
  --assignee marco.presta@hrsdc-rhdcc.gc.ca `
  --role "Storage Blob Data Reader" `
  --scope "/subscriptions/.../storageAccounts/evafinopshueodbqqq6g72kc"

# Download Power BI Desktop template
# Connect using Azure AD authentication (not storage account key)
```

#### Issue 5: Data Factory Pipeline Fails with "File Not Found"

**Symptom**: FinOps Hub pipeline fails at ingestion step, looking for /msexports/MarcoSub/YYYYMMDD/ActualCost_*.csv  
**Cause**: Daily export not configured yet, or export failed to execute  
**Solution**:
```powershell
# Check if export exists
az costmanagement export show `
  --name "FinOpsExport-MarcoSub-Daily" `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a"

# If not found, create export
az costmanagement export create `
  --name "FinOpsExport-MarcoSub-Daily" `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a" `
  --storage-container "msexports" `
  --recurrence "Daily"

# Execute export manually
az costmanagement export execute `
  --name "FinOpsExport-MarcoSub-Daily" `
  --scope "/subscriptions/c59ee575-eb2a-4b51-a865-4b618f9add0a"

# Wait 5-10 minutes, then check blob storage
az storage blob list `
  --account-name evafinopshueodbqqq6g72kc `
  --container-name msexports `
  --prefix "MarcoSub/" `
  --output table
```

### Performance Optimization

**SDK vs FinOps Hub Decision Matrix**:

| Scenario | Recommended Tool | Reason |
|----------|------------------|--------|
| Ad-hoc cost analysis | Azure SDK (`extract_costs_sdk.py`) | Fast (1 min), on-demand |
| Monthly reporting | FinOps Hub (Power BI) | Automated, enterprise-grade dashboards |
| Resource audits | Azure SDK (`azure_inventory.py`) | Tag compliance checks |
| Budget tracking | FinOps Hub | Persistent storage, historical trends |
| Emergency cost check | Azure SDK | 1-minute turnaround vs 10-min pipeline |
| Historical bulk load | Azure SDK | Programmatic date range, 11 months in 1-2 min |
| Daily automation | FinOps Hub | Zero-touch scheduled exports |

**Performance Metrics**:
- **SDK Extraction**: <1 minute for 30 days, 1-2 minutes for 11 months
- **FinOps Hub Pipeline**: 5-10 minutes (ingestion + transformation + FOCUS normalization)
- **Code Efficiency**: 64% reduction (883 lines PowerShell → 267 lines Python)
- **Time Savings**: 95% faster (12-19 min manual → 1 min SDK)

**Optimization Tips**:
1. Use SDK for exploratory analysis, FinOps Hub for recurring reporting
2. Load seed data once with SDK, rely on daily exports for increments
3. Query Data Factory pipeline status before triggering manual execution
4. Use `--output table` for faster CLI queries vs JSON parsing
5. Schedule Power BI refresh after Data Factory pipeline completion (avoid empty reports)

---

**For comprehensive architecture details, see [architecture-ai-context.md](./architecture-ai-context.md)**

<!--
PRESERVED EXISTING PART 2 CONTENT (Review and integrate manually):

This content was backed up before deployment. Review the sections below and:
1. Copy useful project-specific patterns to appropriate [TODO] sections above
2. Remove this comment block when integration is complete

## PART 2: 14-az-finops PROJECT SPECIFIC

-->
