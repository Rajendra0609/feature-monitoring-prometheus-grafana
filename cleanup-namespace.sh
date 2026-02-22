#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <namespace1> [namespace2 ...]" >&2
  exit 2
}

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found in PATH" >&2
  exit 3
fi

[[ $# -ge 1 ]] || usage

force_delete_stuck_pods() {
  local ns=$1
  echo "[${ns}] Force-deleting pods stuck in Terminating/Unknown (if any)"
  mapfile -t stuck < <(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '/Terminating|Unknown/ {print $1}')
  if [[ ${#stuck[@]} -gt 0 ]]; then
    for p in "${stuck[@]}"; do
      echo "[${ns}] Force delete pod: $p"
      kubectl delete pod "$p" -n "$ns" --grace-period=0 --force || true
    done
  fi
}

wait_for_no_pods() {
  local ns=$1
  for i in {1..6}; do
    local remaining
    remaining=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$remaining" == "0" ]]; then
      echo "[${ns}] No pods remain"
      return 0
    fi
    echo "[${ns}] Pods remaining: $remaining — re-checking (attempt $i/6)"
    sleep 5
    force_delete_stuck_pods "$ns"
  done
  return 1
}

cleanup_pvcs_and_pvs() {
  local ns=$1
  echo "[${ns}] Cleaning PVCs and PVs"
  # Iterate PVCs (name:pv)
  while IFS=: read -r pvc pv; do
    [[ -z "$pvc" ]] && continue
    echo "[${ns}] PVC: $pvc (PV: ${pv:-none})"
    kubectl patch pvc "$pvc" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
    kubectl delete pvc "$pvc" -n "$ns" --wait=false >/dev/null 2>&1 || true
    if [[ -n "${pv:-}" && "$pv" != "<none>" ]]; then
      echo "[${ns}] Unbinding/cleaning PV: $pv"
      kubectl patch pv "$pv" --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]' >/dev/null 2>&1 || true
      kubectl patch pv "$pv" -p '{"spec":{"claimRef":null}}' --type=merge >/dev/null 2>&1 || true
      kubectl patch pv "$pv" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
      kubectl delete pv "$pv" --wait=false >/dev/null 2>&1 || true
    fi
  done < <(kubectl get pvc -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.volumeName}{"\n"}{end}' 2>/dev/null || true)

  echo "[${ns}] Force cleaning any remaining PVCs"
  mapfile -t pvcs < <(kubectl get pvc -n "$ns" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | awk '{print $1}')
  for pvc in "${pvcs[@]:-}"; do
    [[ -z "$pvc" ]] && continue
    echo "[${ns}] Removing finalizers for PVC: $pvc"
    kubectl patch pvc "$pvc" -n "$ns" --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' >/dev/null 2>&1 || true
    kubectl patch pvc "$pvc" -n "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
    echo "[${ns}] Deleting PVC: $pvc"
    kubectl delete pvc "$pvc" -n "$ns" --wait=false >/dev/null 2>&1 || true
  done
}

unbind_pvs_for_namespace() {
  local ns=$1
  echo "[${ns}] Making PVs Available that reference this namespace"
  while IFS=: read -r pvname nsref pvcref; do
    [[ "$nsref" != "$ns" ]] && continue
    echo "[${ns}] Unbinding PV: $pvname (was bound to $nsref/$pvcref)"
    kubectl patch pv "$pvname" --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]' >/dev/null 2>&1 || true
    kubectl patch pv "$pvname" -p '{"spec":{"claimRef":null}}' --type=merge >/dev/null 2>&1 || true
    kubectl patch pv "$pvname" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
  done < <(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}:{.spec.claimRef.namespace}:{.spec.claimRef.name}{"\n"}{end}' 2>/dev/null || true)
}

delete_namespace_and_remove_finalizers() {
  local ns=$1
  echo "[${ns}] Deleting namespace"
  kubectl delete namespace "$ns" --wait=false >/dev/null 2>&1 || true
  echo "[${ns}] Removing namespace finalizers (if stuck)"
  kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1 || true
  kubectl patch namespace "$ns" --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' >/dev/null 2>&1 || true
}

main() {
  for ns in "$@"; do
    echo "=== Cleaning namespace: $ns ==="
    force_delete_stuck_pods "$ns"
    wait_for_no_pods "$ns" || true
    cleanup_pvcs_and_pvs "$ns"
    unbind_pvs_for_namespace "$ns"
    delete_namespace_and_remove_finalizers "$ns"
    echo "[${ns}] Done. Current PVs (grep Available to see freed volumes):"
    kubectl get pv || true
  done
  echo "Tip: verify deletion with: kubectl get ns"
}

main "$@"

