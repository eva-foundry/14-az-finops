# Agent Skills Implementation Options: Comprehensive Comparison

**Date**: February 17, 2026  
**Project**: EVA FinOps Enterprise Roadmap  
**Context**: Evaluating implementation approaches for agent skills to support evidence-based Azure deployment and cost management

---

## Executive Summary

This document compares **5 implementation approaches** for deploying the 10 recommended agent skills (Tier 1-3) identified in the FinOps roadmap. The comparison includes **Microsoft AI Foundry (Azure AI Foundry)** as the enterprise-grade orchestration option alongside MCP, VS Code extensions, Python utilities, and a hybrid approach.

**Recommendation**: Start with **Python Utilities (Option 4)** + **MCP Servers (Option 2)** for rapid value delivery, then evaluate **AI Foundry (Option 1)** for multi-agent orchestration when team scales beyond 5 developers.

---

## Option 1: Microsoft AI Foundry (Azure AI Foundry) - Agents

**Description**: Microsoft's enterprise-grade AI orchestration platform (formerly Azure AI Studio) with native agent capabilities.

### Architecture
```
Azure AI Foundry Project
├── Agent Pool (specialized agents)
│   ├── AzureInventoryAgent (Tier 1 skill)
│   ├── EvidenceBasedCodeGenAgent (Tier 1 skill)
│   ├── GapAnalysisAgent (Tier 1 skill)
│   └── IaCValidationAgent (Tier 2 skill)
├── Shared Resources
│   ├── Azure OpenAI (gpt-4o, embeddings)
│   ├── Azure AI Search (RAG over .eva-cache/)
│   ├── Azure Cosmos DB (agent state, memory)
│   └── Azure Blob Storage (artifacts, evidence)
└── Integration
    ├── VS Code Extension (AI Foundry SDK)
    ├── GitHub Copilot (via REST API)
    └── PowerShell/CLI (az ai agent commands)
```

### Pros
✅ **Enterprise-grade**: Built for production, SOC 2 compliant, RBAC integration  
✅ **Native Azure integration**: Direct access to all Azure services (Storage, Cosmos DB, ADX, APIM)  
✅ **Agent orchestration**: Multi-agent workflows, built-in memory, function calling  
✅ **Managed infrastructure**: No server management, auto-scaling, monitoring via Azure Monitor  
✅ **RAG-ready**: Native Azure AI Search integration for `.eva-cache` inventory lookups  
✅ **Cost tracking**: Built-in token usage tracking, cost attribution per agent  
✅ **Security**: Managed identities, Key Vault integration, private endpoints  

### Cons
❌ **Cost**: ~$200-400/month for agent compute + OpenAI usage (PTU or PAYG)  
❌ **Learning curve**: New platform, SDK still maturing (preview features)  
❌ **Vendor lock-in**: Tight coupling to Azure ecosystem  
❌ **Latency**: Agent invocations require REST API calls (100-300ms overhead)  
❌ **Limited local dev**: Requires Azure subscription for testing (no full offline mode)  

### Best For
- **Production deployments** with enterprise governance requirements
- **Multi-agent workflows** (e.g., InventoryAgent → GapAnalysisAgent → IaCGenAgent pipeline)
- **Azure-centric shops** already using Azure AI Services
- **Cost visibility**: Built-in metering for chargeback/showback

### Implementation Effort
- **Setup**: 2-4 hours (AI Foundry project, agents, connections)
- **Integration**: 8-12 hours (VS Code extension, Copilot bridge)
- **Maintenance**: Low (managed service)

### Code Sample
```python
# Azure AI Foundry Agent SDK (Python)
from azure.ai.agents import AgentsClient
from azure.identity import DefaultAzureCredential

# Initialize client
client = AgentsClient(
    endpoint="https://your-foundry-project.azureaiservices.net",
    credential=DefaultAzureCredential()
)

# Create Azure Inventory Agent
inventory_agent = client.create_agent(
    model="gpt-4o",
    name="AzureInventoryValidator",
    instructions="""
You are an Azure resource inventory expert. Your job:
1. Parse JSON files from /tools/finops/out/*.json
2. Validate resource names against actual inventory
3. Return UNKNOWN if resource not found in cache
4. Cite evidence: file path + timestamp
""",
    tools=[
        {"type": "file_search"},  # RAG over .eva-cache
        {"type": "code_interpreter"},  # Parse JSON
        {"type": "function", "function": {
            "name": "get_azure_inventory",
            "description": "Retrieve Azure resource by name/type",
            "parameters": {
                "type": "object",
                "properties": {
                    "resource_name": {"type": "string"},
                    "resource_type": {"type": "string"}
                }
            }
        }}
    ]
)

# Invoke agent with task
response = client.run_agent(
    agent_id=inventory_agent.id,
    thread_id="finops-phase1-deployment",
    message="Validate that storage account 'marcosandboxfinopshub' exists in EsDAICoESub"
)
print(response.content)
```

---

## Option 2: Model Context Protocol (MCP) Servers

**Description**: Anthropic's open protocol for AI tool integration, portable across multiple AI platforms (Claude, ChatGPT, GitHub Copilot).

### Architecture
```
MCP Ecosystem
├── MCP Servers (TypeScript/Python)
│   ├── @eva/azure-inventory-mcp
│   ├── @eva/evidence-based-codegen-mcp
│   ├── @eva/gap-analysis-mcp
│   └── @eva/iac-validation-mcp
├── MCP Clients
│   ├── VS Code Extension (Copilot integration)
│   ├── Claude Desktop
│   ├── Windsurf IDE
│   └── Custom clients (Python, Node.js)
└── Shared Context
    ├── Local filesystem (.eva-cache/)
    ├── Azure SDK (via managed identity)
    └── Git repositories
```

### Pros
✅ **Portability**: Works with Claude, ChatGPT, Copilot, custom UIs  
✅ **Open standard**: No vendor lock-in, community-driven  
✅ **Local-first**: Runs on DevBox, no cloud dependency for tools  
✅ **Cost-effective**: $0 infrastructure cost (serverless on client machine)  
✅ **Rapid development**: TypeScript/Python, hot-reload during dev  
✅ **Composable**: Mix and match tools from different MCP servers  
✅ **Privacy**: Sensitive data stays local (no cloud transmission)  

### Cons
❌ **No orchestration**: MCP is tool protocol, not agent framework (need custom orchestrator)  
❌ **Client-dependent**: Each tool invocation runs on client machine (no shared state across users)  
❌ **No built-in memory**: MCP servers are stateless (need external store like Cosmos DB)  
❌ **Limited observability**: No native tracing/monitoring (need custom instrumentation)  
❌ **Manual deployment**: No centralized management (each dev installs MCP servers locally)  

### Best For
- **Individual developer productivity** (local tools, fast iteration)
- **Cross-platform AI tools** (use same tools with Claude, ChatGPT, Copilot)
- **Offline scenarios** (DevBox without internet)
- **Open source projects** (community-contributed tools)

### Implementation Effort
- **Setup**: 4-6 hours (MCP servers, NPM packages, VS Code config)
- **Integration**: 6-10 hours (GitHub Copilot bridge via MCP SDK)
- **Maintenance**: Medium (manual updates, client-side deployment)

### Code Sample
```typescript
// MCP Server: Azure Inventory Validator
// File: @eva/azure-inventory-mcp/src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import fs from "fs/promises";
import path from "path";

const INVENTORY_PATH = "i:/eva-foundation/14-az-finops/tools/finops/out";

const server = new Server(
  {
    name: "eva-azure-inventory",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool: Validate Azure Resource
server.setRequestHandler(
  "tools/call",
  async (request) => {
    const { name, arguments: args } = request.params;
    
    if (name === "validate_azure_resource") {
      const { resourceName, resourceType } = z.object({
        resourceName: z.string(),
        resourceType: z.string(),
      }).parse(args);
      
      // Read inventory JSON (latest file)
      const files = await fs.readdir(INVENTORY_PATH);
      const inventoryFiles = files.filter(f => f.startsWith("storage-accounts-"));
      if (inventoryFiles.length === 0) {
        return {
          content: [{
            type: "text",
            text: `[UNKNOWN] No inventory file found. Run az-inventory-finops.ps1 first.`
          }],
          isError: false
        };
      }
      
      const latestFile = inventoryFiles.sort().pop();
      const inventoryPath = path.join(INVENTORY_PATH, latestFile!);
      const inventory = JSON.parse(await fs.readFile(inventoryPath, "utf-8"));
      
      // Search for resource
      const found = inventory.find((r: any) => 
        r.name === resourceName && r.type.includes(resourceType)
      );
      
      if (found) {
        return {
          content: [{
            type: "text",
            text: `[VERIFIED] Resource exists: ${resourceName}\nEvidence: ${inventoryPath}\nResource Group: ${found.resourceGroup}\nLocation: ${found.location}`
          }]
        };
      } else {
        return {
          content: [{
            type: "text",
            text: `[UNKNOWN] Resource "${resourceName}" not found in inventory.\nLast verified: ${latestFile}\nSuggestion: Resource may exist but not captured in last inventory run.`
          }]
        };
      }
    }
    
    throw new Error(`Unknown tool: ${name}`);
  }
);

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

**VS Code Configuration** (`settings.json`):
```json
{
  "github.copilot.advanced": {
    "mcpServers": {
      "eva-azure-inventory": {
        "command": "node",
        "args": ["i:/eva-foundation/mcp-servers/azure-inventory-mcp/dist/index.js"]
      }
    }
  }
}
```

---

## Option 3: VS Code Extension (Native GitHub Copilot Integration)

**Description**: TypeScript extension that directly integrates with GitHub Copilot Chat API in VS Code.

### Architecture
```
VS Code Extension
├── Extension Host (TypeScript)
│   ├── Copilot Chat Participant (@eva-finops)
│   ├── Command Palette Commands
│   ├── Quick Fixes / Code Actions
│   └── Status Bar Items
├── Language Services
│   ├── JSON/JSONC (inventory files)
│   ├── Bicep (IaC validation)
│   ├── KQL (ADX queries)
│   └── PowerShell (scripts)
└── Backend Services
    ├── Azure SDK (inventory queries)
    ├── File watchers (.eva-cache/)
    └── Git integration (evidence tracking)
```

### Pros
✅ **Native integration**: Best GitHub Copilot experience (chat participants, inline suggestions)  
✅ **Rich UI**: Custom webviews, tree views, diagnostics panel  
✅ **Context-aware**: Full access to workspace state, open files, Git history  
✅ **LSP integration**: Syntax validation, IntelliSense, symbol search  
✅ **Publish to Marketplace**: Share with team or public  
✅ **Offline capable**: Core features work without internet  

### Cons
❌ **VS Code only**: Won't work in other editors (JetBrains, Sublime, Vim)  
❌ **Maintenance burden**: Extension API changes, Copilot API updates  
❌ **Distribution complexity**: VSIX packaging, version management, update notifications  
❌ **No multi-user state**: Each dev has isolated extension instance  
❌ **Limited language support**: TypeScript required (no Python)  

### Best For
- **Team standardization** (everyone uses VS Code + Copilot)
- **Tight IDE integration** (diagnostics, quick fixes, code lens)
- **Custom UIs** (webview panels for inventory visualization, gap reports)
- **Language-specific features** (Bicep validation, KQL syntax checking)

### Implementation Effort
- **Setup**: 8-12 hours (extension scaffolding, manifest, activation events)
- **Integration**: 12-20 hours (chat participant, commands, UI)
- **Maintenance**: Medium-High (API changes, testing, publishing)

### Code Sample
```typescript
// VS Code Extension: EVA FinOps Assistant
// File: extension.ts
import * as vscode from 'vscode';

export function activate(context: vscode.ExtensionContext) {
  // Register Chat Participant
  const participant = vscode.chat.createChatParticipant(
    'eva-finops',
    async (
      request: vscode.ChatRequest,
      context: vscode.ChatContext,
      stream: vscode.ChatResponseStream,
      token: vscode.CancellationToken
    ) => {
      // Parse user request
      if (request.command === 'validate-resource') {
        const resourceName = request.prompt.trim();
        
        // Read inventory from workspace
        const inventoryUri = vscode.Uri.file(
          'i:/eva-foundation/14-az-finops/tools/finops/out'
        );
        const files = await vscode.workspace.fs.readDirectory(inventoryUri);
        const latestInventory = files
          .filter(([name]) => name.startsWith('storage-accounts-'))
          .sort()
          .pop();
        
        if (!latestInventory) {
          stream.markdown('[UNKNOWN] No inventory found. Run:\n```powershell\n.\\az-inventory-finops.ps1\n```');
          return;
        }
        
        const inventoryPath = vscode.Uri.joinPath(inventoryUri, latestInventory[0]);
        const inventoryData = await vscode.workspace.fs.readFile(inventoryPath);
        const inventory = JSON.parse(inventoryData.toString());
        
        // Search for resource
        const found = inventory.find((r: any) => r.name === resourceName);
        
        if (found) {
          stream.markdown(`[VERIFIED] \`${resourceName}\` exists\n\n`);
          stream.markdown(`**Evidence**: [${latestInventory[0]}](${inventoryPath.toString()})\n`);
          stream.markdown(`**Resource Group**: ${found.resourceGroup}\n`);
          stream.markdown(`**Location**: ${found.location}`);
        } else {
          stream.markdown(`[UNKNOWN] \`${resourceName}\` not in inventory`);
          
          // Suggest inventory refresh
          stream.button({
            command: 'eva-finops.refresh-inventory',
            title: 'Refresh Inventory'
          });
        }
      }
    }
  );
  
  context.subscriptions.push(participant);
  
  // Register Command: Refresh Inventory
  context.subscriptions.push(
    vscode.commands.registerCommand('eva-finops.refresh-inventory', async () => {
      const terminal = vscode.window.createTerminal('EVA FinOps Inventory');
      terminal.sendText('cd i:/eva-foundation/14-az-finops/tools/finops');
      terminal.sendText('.\\az-inventory-finops.ps1');
      terminal.show();
    })
  );
}
```

**Package.json**:
```json
{
  "name": "eva-finops-assistant",
  "displayName": "EVA FinOps Assistant",
  "version": "1.0.0",
  "publisher": "esdc-aicoe",
  "engines": {
    "vscode": "^1.85.0"
  },
  "contributes": {
    "chatParticipants": [
      {
        "id": "eva-finops",
        "name": "EVA FinOps",
        "description": "Azure FinOps inventory and deployment assistant",
        "commands": [
          {
            "name": "validate-resource",
            "description": "Validate Azure resource exists in inventory"
          },
          {
            "name": "generate-bicep",
            "description": "Generate Bicep code with evidence citations"
          }
        ]
      }
    ],
    "commands": [
      {
        "command": "eva-finops.refresh-inventory",
        "title": "EVA FinOps: Refresh Inventory"
      }
    ]
  }
}
```

---

## Option 4: Python Utilities (Callable Functions)

**Description**: Standalone Python modules that provide agent-like capabilities as importable functions (no AI orchestration).

### Architecture
```
Python Utilities
├── eva_finops/
│   ├── __init__.py
│   ├── inventory.py (Azure resource validation)
│   ├── evidence.py (Citation generation)
│   ├── gap_analysis.py (Gap detection logic)
│   └── iac_generator.py (Bicep/Terraform generation)
├── Integration Points
│   ├── PowerShell scripts (Import-Module, call Python)
│   ├── GitHub Actions (Python steps)
│   ├── Jupyter Notebooks (exploratory analysis)
│   └── Copilot (via @workspace context)
└── Storage
    ├── SQLite (local cache)
    ├── JSON files (.eva-cache/)
    └── Azure Blob (evidence artifacts)
```

### Pros
✅ **Language flexibility**: Python everywhere (scripts, notebooks, Actions)  
✅ **No AI dependency**: Pure logic, no tokens spent  
✅ **Testable**: Unit tests, mocks, CI/CD integration  
✅ **Lightweight**: No server, no extension, just `pip install`  
✅ **Reusable**: Call from any Python environment  
✅ **Version control**: Standard Git workflow for updates  

### Cons
❌ **No AI integration**: Copilot can't directly call these (need @workspace mentions)  
❌ **Manual orchestration**: Dev must chain functions manually  
❌ **No natural language interface**: Requires code-level interaction  
❌ **Limited discoverability**: Devs need to know functions exist  
❌ **No context management**: Dev responsible for passing state between functions  

### Best For
- **Scripting/automation** (PowerShell, GitHub Actions, cron jobs)
- **Data analysis** (Jupyter notebooks, cost trend analysis)
- **Testing/validation** (pre-commit hooks, CI/CD gates)
- **Low-level building blocks** (used by other agent implementations)

### Implementation Effort
- **Setup**: 4-6 hours (module structure, packaging, tests)
- **Integration**: 2-4 hours (import into scripts, document usage)
- **Maintenance**: Low (pure code, no external dependencies beyond Azure SDK)

### Code Sample
```python
# File: eva_finops/inventory.py
from pathlib import Path
from datetime import datetime, timedelta
import json
from typing import Optional, Dict, Any

class AzureInventoryValidator:
    """Validate Azure resources against cached inventory"""
    
    def __init__(self, inventory_path: Path = Path("i:/eva-foundation/14-az-finops/tools/finops/out")):
        self.inventory_path = inventory_path
        self._cache_ttl = timedelta(hours=24)
    
    def validate_resource(self, resource_name: str, resource_type: str) -> Dict[str, Any]:
        """
        Validate if Azure resource exists in inventory.
        
        Args:
            resource_name: Name of Azure resource (e.g., "marcosandboxfinopshub")
            resource_type: Azure resource type (e.g., "storage", "apim", "adx")
        
        Returns:
            Dict with:
            - status: "VERIFIED" | "UNKNOWN" | "STALE"
            - evidence: File path to inventory JSON
            - resource: Resource metadata (if found)
            - message: Human-readable result
        """
        # Find latest inventory file for resource type
        pattern = f"{resource_type}-*.json"
        matching_files = list(self.inventory_path.glob(pattern))
        
        if not matching_files:
            return {
                "status": "UNKNOWN",
                "evidence": None,
                "resource": None,
                "message": f"[UNKNOWN] No inventory file found for type '{resource_type}'. Run az-inventory-finops.ps1"
            }
        
        # Get most recent inventory
        latest_file = max(matching_files, key=lambda p: p.stat().st_mtime)
        
        # Check if inventory is stale
        file_age = datetime.now() - datetime.fromtimestamp(latest_file.stat().st_mtime)
        if file_age > self._cache_ttl:
            return {
                "status": "STALE",
                "evidence": str(latest_file),
                "resource": None,
                "message": f"[STALE] Inventory is {file_age.total_seconds() / 3600:.1f} hours old. Refresh recommended."
            }
        
        # Load and search inventory
        with open(latest_file, 'r', encoding='utf-8') as f:
            inventory = json.load(f)
        
        # Search for resource (handle list or dict structure)
        resources = inventory if isinstance(inventory, list) else inventory.get('resources', [])
        found = next((r for r in resources if r.get('name') == resource_name), None)
        
        if found:
            return {
                "status": "VERIFIED",
                "evidence": str(latest_file),
                "resource": found,
                "message": f"[VERIFIED] {resource_name} exists\nResource Group: {found.get('resourceGroup')}\nLocation: {found.get('location')}\nEvidence: {latest_file.name}"
            }
        else:
            return {
                "status": "UNKNOWN",
                "evidence": str(latest_file),
                "resource": None,
                "message": f"[UNKNOWN] {resource_name} not found in inventory.\nEvidence checked: {latest_file.name}\nSuggestion: Resource may exist but not in last scan."
            }

# Usage in scripts
if __name__ == "__main__":
    validator = AzureInventoryValidator()
    
    # Example: Validate storage account
    result = validator.validate_resource("marcosandboxfinopshub", "storage-accounts")
    print(result["message"])
    
    if result["status"] == "VERIFIED":
        print(f"\n[PASS] Resource confirmed in Azure")
    else:
        print(f"\n[WARN] Cannot confirm resource existence")
```

**PowerShell Integration**:
```powershell
# Call Python utility from PowerShell
$pythonExe = "python"
$scriptPath = "i:\eva-foundation\14-az-finops\scripts\validate-resource.py"

$result = & $pythonExe $scriptPath "marcosandboxfinopshub" "storage-accounts" | ConvertFrom-Json

if ($result.status -eq "VERIFIED") {
    Write-Host "[PASS] Resource verified" -ForegroundColor Green
    Write-Host "Resource Group: $($result.resource.resourceGroup)"
} else {
    Write-Host "[WARN] $($result.message)" -ForegroundColor Yellow
}
```

---

## Option 5: Hybrid Approach (MCP + Python + Azure AI Foundry)

**Description**: Combine best of all worlds - MCP for local tools, Python for logic, AI Foundry for orchestration.

### Architecture
```
Hybrid Architecture
├── Tier 1: Local Tools (MCP Servers)
│   ├── Fast validation (inventory lookups)
│   ├── File operations (.eva-cache reads)
│   └── Git operations (evidence tracking)
├── Tier 2: Business Logic (Python Utilities)
│   ├── Gap analysis algorithms
│   ├── Cost optimization models
│   └── IaC generation templates
├── Tier 3: Orchestration (Azure AI Foundry)
│   ├── Multi-agent workflows
│   ├── Complex reasoning (GPT-4)
│   └── State management (Cosmos DB)
└── Integration Layer
    ├── MCP → Python (function calls)
    ├── Python → AI Foundry (REST API)
    └── AI Foundry → MCP (tool invocations)
```

### Pros
✅ **Best of all worlds**: Local speed + enterprise orchestration  
✅ **Cost optimization**: Use MCP for simple tasks, AI Foundry for complex reasoning  
✅ **Flexibility**: Choose tool per task (local vs cloud)  
✅ **Scalability**: Start with MCP, graduate to AI Foundry as needed  
✅ **Testability**: Python utilities testable without AI dependency  

### Cons
❌ **Complexity**: Three systems to maintain  
❌ **Learning curve**: Team needs to understand multiple paradigms  
❌ **Debugging difficulty**: Multi-layer stack traces  
❌ **Infrastructure cost**: Still paying for AI Foundry (though less usage)  

### Best For
- **Enterprise deployments** with mixed requirements (local dev + production orchestration)
- **Cost-conscious teams** (use local tools for 80% of tasks, cloud for 20%)
- **Mature DevOps** with CI/CD pipelines

---

## Recommendation Matrix

| Criterion | AI Foundry | MCP | VS Code Ext | Python Utils | Hybrid |
|-----------|-----------|-----|-------------|--------------|--------|
| **Cost** | $$$ | $ | $ | $ | $$ |
| **Speed (local)** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Enterprise-ready** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Learning curve** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Portability** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Multi-agent** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ |
| **Observability** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Time to MVP** | 2-3 weeks | 1 week | 2 weeks | 3-5 days | 3-4 weeks |

---

## Recommended Approach for FinOps Project

**Start with: Option 4 (Python Utilities) + Option 2 (MCP)**

### Phase 1 (Week 1-2): Python Utilities
Build foundational skills as importable functions:
- `eva_finops.inventory.AzureInventoryValidator`
- `eva_finops.evidence.CitationGenerator`
- `eva_finops.gap_analysis.FinOpsGapDetector`

**Why**: 
- Zero infrastructure cost
- Testable, reusable in scripts/Actions
- GitHub Copilot can reference via @workspace
- Foundation for MCP/AI Foundry later

### Phase 2 (Week 3): MCP Servers
Wrap Python utilities as MCP tools:
- `@eva/azure-inventory-mcp` (calls `AzureInventoryValidator`)
- `@eva/evidence-codegen-mcp` (calls `CitationGenerator`)

**Why**:
- Enables Copilot Chat participants
- Works in VS Code, Claude Desktop, Windsurf
- Local-first, no cloud dependency

### Phase 3 (Week 4-6): Evaluate AI Foundry
Once you have 10+ working skills and need:
- Multi-agent workflows (Inventory → Gap Analysis → IaC Gen pipeline)
- Shared state across team members
- Cost attribution per skill invocation

**Upgrade decision criteria**:
- Team size >5 developers
- Monthly token usage >$500/month (then PTU reservation makes sense)
- Need for audit logs/enterprise governance

---

## Cost Comparison (Monthly)

| Option | Infrastructure | Development | Maintenance | Total Est. |
|--------|---------------|-------------|-------------|-----------|
| **AI Foundry** | $200-400 | $0 (managed) | $50 (monitoring) | $250-450 |
| **MCP** | $0 | $80 (updates) | $40 (client updates) | $120 |
| **VS Code Ext** | $0 | $100 (API changes) | $60 (testing) | $160 |
| **Python Utils** | $0 | $40 (features) | $20 (tests) | $60 |
| **Hybrid** | $100-200 | $120 | $80 | $300-400 |

*Development costs assume 10 hours/month at $12/hour blended rate*

---

## Next Steps

1. **Immediate** (Today): Generate Python utility `eva_finops/inventory.py`
2. **Week 1**: Build remaining Tier 1 Python utilities (evidence, gap analysis)
3. **Week 2**: Package as MCP server (TypeScript wrapper)
4. **Week 3**: Deploy to team (VS Code configuration)
5. **Week 4-6**: Evaluate AI Foundry for multi-agent orchestration

---

## References

- **Microsoft AI Foundry**: https://azure.microsoft.com/en-us/products/ai-foundry
- **Model Context Protocol**: https://modelcontextprotocol.io
- **VS Code Extension API**: https://code.visualstudio.com/api
- **GitHub Copilot Chat**: https://docs.github.com/en/copilot/building-copilot-extensions

---

**Last Updated**: February 17, 2026  
**Author**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**Status**: Analysis Complete - Ready for Implementation Decision
