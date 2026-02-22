#!/usr/bin/env bash
set -euo pipefail
# small dynamic banner that shows repository name and top-level folders
# colors (fall back to empty strings if stdout isn't a terminal)
if [ -t 1 ]; then
	BOLD="\e[1m"
	BLUE="\e[34m"
	GREEN="\e[32m"
	YELLOW="\e[33m"
	RESET="\e[0m"
else
	BOLD=""
	BLUE=""
	GREEN=""
	YELLOW=""
	RESET=""
fi

print_banner() {
	echo
	printf "%b" "${BOLD}${BLUE}============================================\n"
	printf "%b" "${BOLD}${GREEN}   Node Metrics Prometheus and Grafana  \n"
	printf "%b" "${BOLD}${GREEN} [INFO] To apply PVs set WORKER_NODE_NAME and run ./apply-all.sh\n"
	printf "%b" "${BOLD}${BLUE}============================================${RESET}\n"
	echo
	printf "%b" "${YELLOW}Top-level folders:${RESET}\n"
	# list top-level directories (skip hidden/empty)
	for d in $(ls -1d */ 2>/dev/null | sort); do
		printf "  - %s\n" "${d%/}"
	done
	echo
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# show banner for context
print_banner

if ! command -v kubectl >/dev/null 2>&1; then
	echo "kubectl is not installed or not in PATH" >&2
	exit 2
fi

# =============================================================================
# Helper functions - must be defined before use
# =============================================================================

# helper: detect likely runtime dump manifests (contain status/resourceVersion/uid/hostIP)
is_runtime_dump() {
	local file="$1"
	if grep -Eq "^\s*(resourceVersion:|uid:|status:|hostIP:|containerStatuses:|ownerReferences:)" "$file"; then
		return 0
	fi
	return 1
}

# helper: detect PV placeholders (WORKER_NODE_NAME or default hostnames)
has_storage_placeholder() {
	local file="$1"
	if grep -Eq "(WORKER_NODE_NAME|k8s-worker1|k8s-worker)" "$file"; then
		return 0
	fi
	return 1
}

apply_file() {
	local file="$1"
	# skip empty files
	[ -s "$file" ] || return 0
	if is_runtime_dump "$file"; then
		echo "[SKIP] Runtime dump detected, skipping: $file"
		return 0
	fi
	if [[ "${file#05-storage/}" != "$file" ]] && has_storage_placeholder "$file"; then
		# If WORKER_NODE_NAME is set, substitute it and apply the temporary file
		if [ -n "${WORKER_NODE_NAME:-}" ]; then
			TMPFILE=$(mktemp 2>/dev/null || echo "/tmp/apply-all.$$")
			sed "s/WORKER_NODE_NAME/${WORKER_NODE_NAME}/g" "$file" > "$TMPFILE"
			echo "[INFO] Applying storage PV with WORKER_NODE_NAME=${WORKER_NODE_NAME}: $file"
			kubectl apply -f "$TMPFILE"
			rm -f "$TMPFILE"
			return 0
		else
			echo "[WARN] Storage PV contains placeholder hostnames; set WORKER_NODE_NAME env var or edit before applying: $file"
			return 0
		fi
	fi
	echo "[INFO] Applying file: $file"
	kubectl apply -f "$file"
}

# =============================================================================
# Main logic - apply resources in order
# =============================================================================

# 1) Namespaces (apply exact file if present)
if [ -f 00-namespaces/00-namespaces.yaml ]; then
	echo "[INFO] Applying namespaces: 00-namespaces/00-namespaces.yaml"
	kubectl apply -f 00-namespaces/00-namespaces.yaml
else
	echo "[WARN] 00-namespaces/00-namespaces.yaml not found; continuing"
fi

# Apply directories in a safe, explicit order so PVs/storage exist before workloads
ordered_dirs=(
	"00-namespaces"
	"05-storage"
	"01-node-metrics"
	"02-monitoring"
	"04-jenkins-integration"
)

for od in "${ordered_dirs[@]}"; do
	if [ -d "$od" ]; then
		echo "[INFO] Applying ordered directory: $od/"
		while IFS= read -r -d '' f; do
			apply_file "$f"
		done < <(find "$od" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | sort -z)
	else
		echo "[INFO] Ordered path $od not present; skipping"
	fi
done

# helper: detect likely runtime dump manifests (contain status/resourceVersion/uid/hostIP)
is_runtime_dump() {
	local file="$1"
	if grep -Eq "^\s*(resourceVersion:|uid:|status:|hostIP:|containerStatuses:|ownerReferences:)" "$file"; then
		return 0
	fi
	return 1
}

# helper: detect PV placeholders (WORKER_NODE_NAME or default hostnames)
has_storage_placeholder() {
	local file="$1"
	if grep -Eq "(WORKER_NODE_NAME|k8s-worker1|k8s-worker)" "$file"; then
		return 0
	fi
	return 1
}

apply_file() {
	local file="$1"
	# skip empty files
	[ -s "$file" ] || return 0
	if is_runtime_dump "$file"; then
		echo "[SKIP] Runtime dump detected, skipping: $file"
		return 0
	fi
	if [[ "${file#05-storage/}" != "$file" ]] && has_storage_placeholder "$file"; then
		# If WORKER_NODE_NAME is set, substitute it and apply the temporary file
		if [ -n "${WORKER_NODE_NAME:-}" ]; then
			TMPFILE=$(mktemp 2>/dev/null || echo "/tmp/apply-all.$$")
			sed "s/WORKER_NODE_NAME/${WORKER_NODE_NAME}/g" "$file" > "$TMPFILE"
			echo "[INFO] Applying storage PV with WORKER_NODE_NAME=${WORKER_NODE_NAME}: $file"
			kubectl apply -f "$TMPFILE"
			rm -f "$TMPFILE"
			return 0
		else
			echo "[WARN] Storage PV contains placeholder hostnames; set WORKER_NODE_NAME env var or edit before applying: $file"
			return 0
		fi
	fi
	echo "[INFO] Applying file: $file"
	kubectl apply -f "$file"
}

# 2) Apply remaining top-level directories (sorted) excluding 00-namespaces and 05-storage
for d in $(ls -1d */ 2>/dev/null | sort); do
	dir=${d%/}
	# skip directories that were already applied in ordered list
	skip=0
	for od in "${ordered_dirs[@]}"; do
		if [ "$od" = "$dir" ]; then
			skip=1
			break
		fi
	done
	[ "$skip" -eq 1 ] && continue
	echo "[INFO] Applying directory: $d"
	while IFS= read -r -d '' f; do
		apply_file "$f"
	done < <(find "$d" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0 | sort -z)
done

# 3) Apply any top-level YAML/YML files not in directories
shopt -s nullglob
for f in *.yaml *.yml; do
	case "$f" in
		00-namespaces) continue ;;
	esac
	apply_file "$f"
done

sleep 60
# 1) Add the label to the pod template of the Deployment (triggers a rollout)
kubectl -n monitoring patch deploy grafana --type='merge' \
  -p '{"spec":{"template":{"metadata":{"labels":{"app":"grafana"}}}}}'

# 2) Watch the rollout to completion
kubectl -n monitoring rollout status deploy grafana

# 3) Verify Service endpoints are now populated
kubectl -n monitoring get ep grafana -o wide

# 4) Test NodePort again (from any node, because ExternalTrafficPolicy=Cluster)
#curl -I http://192.168.0.103:32000
