# SYSTEM CONTEXT: CADDY REVERSE PROXY PROPOSAL (FINAL)

## 1. Objective & Persona
**Persona:** Supportive Peer / Collaborative Engineer.  
**Objective:** Establish a baseline for a secure, rootless deployment on Enterprise Linux (EL) ecosystems. This prompt initiates a "Defense in Depth" infrastructure design focusing on Systemd Quadlets, Socket Activation, and Kernel-level filtering.

## 2. The Proposed Stack
- **OS:** DigitalOcean AlmaLinux 9 Droplet.
- **Firewall:** Native `nftables` (Direct kernel-level filtering, bypassing firewalld).
- **Containerization:** Rootless Podman via **Systemd Quadlets** (`.container` & `.socket`).
- **User Context:** Dedicated `caddy` service user with `loginctl enable-linger` to ensure persistence.
- **Privilege Model:** **Systemd Socket Activation** (Systemd binds 80/443 -> hands FDs 3/4 to Proxy container).
- **SSL/TLS:** Automated ACME lifecycle via Caddy + `sslip.io`.
- **Logging:** Rootless container logs routed to **journald** via Podman `--log-driver=journald`.

## 3. Technical Logic & Constraints
- **Generator Mechanics:** Reliance on `podman-systemd-generator` to translate declarative Quadlet files into transient systemd units.
- **Socket Handoff:** Utilization of `SystemdSocket=true`. Ensure strict alignment between the `Caddyfile` (`bind fd/3 fd/4`) and the `caddy.socket` unit.
- **Reliability:** Systemd (PID 1) must hold the network ports. If the container restarts, the kernel must queue incoming requests to ensure **Hitless Restarts**.
- **Backend Protocol:** Backend services (Flask/Gunicorn) must utilize `ProxyFix` middleware and bind exclusively to `127.0.0.1`.
- **Logging Strategy:** Use **journald** to handle logs instead of file-based logging:
    - Systemd automatically rotates, compresses, and indexes logs.
    - Eliminates file permission issues for rootless users.
    - Logs remain live during container restarts.
- **Nftables Standard:**  
    * `chain input`: policy drop; allow established/related, lo, ssh, and web ports.  
    * `chain forward`: policy drop; defensive posture against unexpected routing.  
    * `chain output`: policy accept.

## 4. Primary Task: Ansible Implementation
Generate a monolithic Ansible playbook targeting `hosts: fastapi` (or the `caddy` service user) that automates:
1. Hardened `nftables` configuration.
2. Rootless Podman setup and User lingering.
3. Deployment of the Quadlet hierarchy (`.socket` and `.container` files).
4. Caddy configuration for FD-binding and **journald logging**.

## 5. Verification Methodology (Testing Details)
The solution must be verifiable via the following commands:
1. **Socket Ownership:** `ss -tulpn | grep -E '80|443'` (Target: `systemd` / PID 1 must own the ports).
2. **FD Inheritance:** `podman exec <container_name> ls -l /proc/self/fd` (Target: Confirm FDs 3 & 4 are active).
3. **Generator Audit:** `podman-systemd-generator --user --dryrun` (Target: Inspect `NotifyAccess` and `ExecStart` flags).
4. **Nftables Integrity:** `nft list ruleset` (Target: Verify `forward` policy is `drop`).
5. **Hitless Restart Validation:**  
   ```bash
   while true; do curl -sI --connect-timeout 1 https://<IP>.sslip.io | grep "200 OK"; sleep 0.1; done
