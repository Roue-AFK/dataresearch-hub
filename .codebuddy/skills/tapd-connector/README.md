# tapd-connector

TAPD 外网 SaaS Skill，绑定 connector **`tapd-apikey`**。

```bash
./scripts/tapd_api.sh GET /workspaces/user_participant_projects
./scripts/tapd_api.sh GET /bugs 'workspace_id=123&limit=20'
```

Registry：

```json
"skill": {
  "enabled": true,
  "skill_id": "tapd-connector",
  "download_url": "<COS>/tapd-connector.zip"
}
```
