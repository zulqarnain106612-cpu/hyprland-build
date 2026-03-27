# CI/CD Automation Command Reference

> Push · Build · Status · Fetch Logs · Retry — every platform, every command.

---

## 1. PUSH

### Git (universal)
```bash
git add .
git commit -m "feat: your message"
git push origin main                        # push to main
git push origin HEAD                        # push current branch
git push --force-with-lease origin main     # safe force push
git push origin main --tags                 # push with tags
git push --set-upstream origin feature/xyz  # push new branch + track
```

### Tag-based trigger (release pipeline)
```bash
git tag v1.2.3
git push origin v1.2.3
git push origin --tags                      # push all tags
```

---

## 2. BUILD

### GitHub Actions (gh CLI)
```bash
gh workflow run build.yml                          # manual trigger
gh workflow run build.yml --ref feature/xyz        # trigger on branch
gh workflow run build.yml -f env=production        # pass input
```

### GitLab CI (glab CLI)
```bash
glab pipeline run                                  # trigger on current branch
glab pipeline run --ref main                       # trigger specific ref
glab pipeline trigger --token $TRIGGER_TOKEN \
  --ref main \
  https://gitlab.com/api/v4/projects/$PROJECT_ID/trigger/pipeline
```

### Jenkins (CLI jar)
```bash
java -jar jenkins-cli.jar -s http://JENKINS_URL \
  build JOB_NAME

java -jar jenkins-cli.jar -s http://JENKINS_URL \
  build JOB_NAME -p BRANCH=main            # with parameter

curl -X POST http://JENKINS_URL/job/JOB_NAME/build \
  --user user:API_TOKEN

curl -X POST "http://JENKINS_URL/job/JOB_NAME/buildWithParameters?BRANCH=main" \
  --user user:API_TOKEN
```

### CircleCI (circleci CLI)
```bash
circleci pipeline trigger \
  --org-slug gh/ORG \
  --project-slug gh/ORG/REPO \
  --branch main
```

### Docker
```bash
docker build -t myapp:latest .
docker build --no-cache -t myapp:latest .
docker build --build-arg ENV=prod -t myapp:prod .
docker compose build
docker compose build --no-cache
```

### Kubernetes (image push → rollout)
```bash
docker push registry/myapp:v1.2.3
kubectl set image deployment/myapp app=registry/myapp:v1.2.3 -n prod
kubectl rollout restart deployment/myapp -n prod
```

### Make / npm / Gradle
```bash
make build
make test
npm run build
npm run build -- --prod
./gradlew build
./gradlew build --info
```

### Terraform
```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform apply -auto-approve     # CI non-interactive
```

### Ansible
```bash
ansible-playbook playbook.yml -i inventory/prod
ansible-playbook playbook.yml -i inventory/prod -e "env=prod"
```

---

## 3. REAL-TIME BUILD STATUS

### GitHub Actions
```bash
# List recent runs
gh run list --workflow=build.yml --limit 10

# Watch live (blocks terminal, streams state)
gh run watch

# Watch specific run ID
gh run watch 12345678

# One-liner: trigger + immediately watch
gh workflow run build.yml && gh run watch $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
```

### GitLab CI
```bash
glab pipeline list                          # list pipelines
glab pipeline status                        # current branch pipeline status
glab pipeline status --pipeline-id 12345

# Poll every 5 seconds (bash loop)
watch -n 5 glab pipeline status
```

### Jenkins
```bash
# Get build status (last build)
curl -s http://JENKINS_URL/job/JOB_NAME/lastBuild/api/json \
  --user user:TOKEN | python3 -m json.tool

# Poll until done
while true; do
  STATUS=$(curl -s http://JENKINS_URL/job/JOB_NAME/lastBuild/api/json \
    --user user:TOKEN | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'] if d['result'] else 'BUILDING')")
  echo "Status: $STATUS"
  [[ "$STATUS" != "BUILDING" ]] && break
  sleep 5
done
```

### CircleCI
```bash
circleci pipeline list --org-slug gh/ORG

# Get workflow status
curl -s "https://circleci.com/api/v2/pipeline/$PIPELINE_ID/workflow" \
  -H "Circle-Token: $CIRCLE_TOKEN" | python3 -m json.tool
```

### Docker (local)
```bash
docker build . 2>&1 | tee build.log        # stream + save
docker compose up --build                   # watch compose build live
```

### Kubernetes rollout
```bash
kubectl rollout status deployment/myapp -n prod         # blocks until complete
kubectl rollout status deployment/myapp --timeout=5m    # with timeout
```

### Terraform
```bash
terraform plan 2>&1 | tee plan.log
```

---

## 4. FETCH FAILED LOGS

### GitHub Actions
```bash
# List failed runs
gh run list --status failure --limit 10

# View failed run logs (downloads to terminal)
gh run view 12345678 --log-failed

# Download full log bundle (zip)
gh run download 12345678 --name logs

# Stream all logs of a run
gh run view 12345678 --log
```

### GitLab CI
```bash
# Get job ID first
glab pipeline list

# Stream job trace log
glab ci trace JOB_ID

# Fetch via API (raw log)
curl -s "https://gitlab.com/api/v4/projects/$PROJECT_ID/jobs/$JOB_ID/trace" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" > failed.log

cat failed.log | grep -i "error\|fail\|exit"
```

### Jenkins
```bash
# Full console log
curl -s http://JENKINS_URL/job/JOB_NAME/lastBuild/consoleText \
  --user user:TOKEN > build.log

# Tail last 200 lines
curl -s "http://JENKINS_URL/job/JOB_NAME/lastBuild/logText/progressiveText?start=0" \
  --user user:TOKEN

# Grep errors from log
curl -s http://JENKINS_URL/job/JOB_NAME/lastBuild/consoleText \
  --user user:TOKEN | grep -iE "error|fail|exception|exit code"
```

### CircleCI
```bash
# Get job number first
curl -s "https://circleci.com/api/v2/pipeline/$PIPELINE_ID/workflow" \
  -H "Circle-Token: $CIRCLE_TOKEN"

# Fetch job output (all steps)
curl -s "https://circleci.com/api/v2/project/gh/ORG/REPO/job/$JOB_NUMBER/output" \
  -H "Circle-Token: $CIRCLE_TOKEN" > circleci_fail.log
```

### Docker
```bash
docker logs CONTAINER_ID
docker logs CONTAINER_ID --tail 100
docker logs CONTAINER_ID 2>&1 | grep -i error   # stderr + stdout
docker compose logs SERVICE_NAME
docker compose logs --tail=50 SERVICE_NAME
```

### Kubernetes
```bash
kubectl logs deployment/myapp -n prod
kubectl logs deployment/myapp -n prod --previous          # crashed pod logs
kubectl logs deployment/myapp -n prod --tail=100
kubectl logs -l app=myapp -n prod --all-containers=true   # all pods

# Fetch and save
kubectl logs deployment/myapp -n prod > app_failure.log 2>&1
grep -i "error\|fatal\|panic" app_failure.log
```

### Terraform
```bash
cat plan.log | grep -i "error\|fail"
TF_LOG=DEBUG terraform apply 2>&1 | tee tf_debug.log
```

### Ansible
```bash
ansible-playbook playbook.yml -i inventory/prod -vvv 2>&1 | tee ansible.log
grep -i "fatal\|error\|failed" ansible.log
```

---

## 5. RETRY FAILED BUILD

### GitHub Actions
```bash
# Re-run all failed jobs in a run
gh run rerun 12345678 --failed

# Re-run entire run
gh run rerun 12345678

# Re-run latest failed run of a workflow
gh run rerun $(gh run list --workflow=build.yml --status failure \
  --limit 1 --json databaseId -q '.[0].databaseId') --failed
```

### GitLab CI
```bash
# Retry a specific job
glab ci retry JOB_ID

# Retry via API
curl -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/jobs/$JOB_ID/retry" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN"

# Retry entire pipeline
curl -X POST "https://gitlab.com/api/v4/projects/$PROJECT_ID/pipelines/$PIPELINE_ID/retry" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN"
```

### Jenkins
```bash
# Rebuild last failed build (Rebuild plugin)
java -jar jenkins-cli.jar -s http://JENKINS_URL \
  build JOB_NAME

# Via REST
curl -X POST http://JENKINS_URL/job/JOB_NAME/lastBuild/rebuild \
  --user user:TOKEN
```

### CircleCI
```bash
# Rerun failed workflow from failed
curl -X POST "https://circleci.com/api/v2/workflow/$WORKFLOW_ID/rerun" \
  -H "Circle-Token: $CIRCLE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"from_failed": true}'
```

### Kubernetes (rollback = retry previous)
```bash
kubectl rollout undo deployment/myapp -n prod
kubectl rollout undo deployment/myapp --to-revision=3 -n prod
kubectl rollout status deployment/myapp -n prod
```

### Terraform (re-apply after fix)
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Ansible (retry failed hosts)
```bash
# Ansible auto-creates a .retry file on failure
ansible-playbook playbook.yml -i inventory/prod \
  --limit @playbook.retry
```

---

## 6. FULL AUTOMATION SCRIPT

> Push · poll status · fetch log on failure · auto-retry · exit on second failure.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ── config ─────────────────────────────────────────────────────────────────
WORKFLOW="build.yml"
BRANCH="main"
MAX_RETRIES=2
POLL_INTERVAL=10
LOG_FILE="ci_failure_$(date +%Y%m%d_%H%M%S).log"

# ── push ───────────────────────────────────────────────────────────────────
echo "[1/4] Pushing to $BRANCH..."
git add .
git commit -m "ci: automated push $(date +%Y-%m-%dT%H:%M:%S)" || echo "Nothing to commit"
git push origin "$BRANCH"

# ── trigger ────────────────────────────────────────────────────────────────
echo "[2/4] Triggering workflow: $WORKFLOW"
gh workflow run "$WORKFLOW" --ref "$BRANCH"
sleep 5

RUN_ID=$(gh run list --workflow="$WORKFLOW" --limit 1 --json databaseId -q '.[0].databaseId')
echo "  → Run ID: $RUN_ID"

# ── poll status ────────────────────────────────────────────────────────────
echo "[3/4] Watching run $RUN_ID..."
ATTEMPT=1

run_and_watch() {
  local rid=$1
  while true; do
    STATUS=$(gh run view "$rid" --json status,conclusion \
      -q '"Status:\(.status) Conclusion:\(.conclusion)"')
    echo "  $(date +%H:%M:%S) $STATUS"

    CONCLUSION=$(gh run view "$rid" --json conclusion -q '.conclusion')
    [[ "$CONCLUSION" != "null" && -n "$CONCLUSION" ]] && break
    sleep "$POLL_INTERVAL"
  done
  echo "$CONCLUSION"
}

CONCLUSION=$(run_and_watch "$RUN_ID")

# ── fetch log + retry loop ─────────────────────────────────────────────────
echo "[4/4] Result: $CONCLUSION"

while [[ "$CONCLUSION" == "failure" && $ATTEMPT -le $MAX_RETRIES ]]; do
  echo ""
  echo "Build FAILED (attempt $ATTEMPT of $MAX_RETRIES). Fetching logs..."
  gh run view "$RUN_ID" --log-failed 2>&1 | tee "$LOG_FILE"
  echo "  → Log saved: $LOG_FILE"
  grep -iE "error|fatal|exit" "$LOG_FILE" | head -30 || true

  echo ""
  echo "Retrying run $RUN_ID..."
  gh run rerun "$RUN_ID" --failed
  sleep 10

  RUN_ID=$(gh run list --workflow="$WORKFLOW" --limit 1 --json databaseId -q '.[0].databaseId')
  echo "  → New Run ID: $RUN_ID"
  CONCLUSION=$(run_and_watch "$RUN_ID")
  ((ATTEMPT++))
done

# ── final exit ─────────────────────────────────────────────────────────────
if [[ "$CONCLUSION" == "success" ]]; then
  echo ""
  echo "Pipeline PASSED."
  exit 0
else
  echo ""
  echo "Pipeline FAILED after $MAX_RETRIES retries. Check $LOG_FILE"
  exit 1
fi
```

### Usage
```bash
chmod +x ci_automate.sh
./ci_automate.sh
```

---

## 7. QUICK REFERENCE TABLE

| Action | GitHub (gh) | GitLab (glab) | Jenkins (curl) | CircleCI (curl) |
|---|---|---|---|---|
| Push trigger | `gh workflow run FILE` | `glab pipeline run` | `curl -X POST .../build` | `curl -X POST .../pipeline/trigger` |
| Watch status | `gh run watch RUN_ID` | `glab pipeline status` | `curl .../lastBuild/api/json` | `curl .../pipeline/PIPE_ID/workflow` |
| Fetch fail log | `gh run view RUN_ID --log-failed` | `glab ci trace JOB_ID` | `curl .../consoleText` | `curl .../job/JOB_NUM/output` |
| Retry failed | `gh run rerun RUN_ID --failed` | `glab ci retry JOB_ID` | `curl .../rebuild` | `curl -d from_failed=true .../workflow/WF_ID/rerun` |

---

## 8. ENVIRONMENT PREREQUISITES

```bash
# GitHub CLI
brew install gh          # macOS
gh auth login

# GitLab CLI
brew install glab
glab auth login

# Jenkins CLI jar
curl -O http://JENKINS_URL/jnlpJars/jenkins-cli.jar

# CircleCI CLI
brew install circleci
circleci setup

# Docker
brew install --cask docker

# kubectl
brew install kubectl

# Terraform
brew install terraform

# Ansible
pip install ansible

# Required env vars (add to ~/.zshrc or .env)
export GITLAB_TOKEN="glpat-xxxx"
export CIRCLE_TOKEN="xxxx"
export JENKINS_USER="user"
export JENKINS_TOKEN="xxxx"
export PROJECT_ID="12345"         # GitLab project numeric ID
```
