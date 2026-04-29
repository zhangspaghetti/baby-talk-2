@echo off
REM ============================================================
REM restore-k8s-proxy.cmd
REM Run this ONCE after every Docker Desktop restart to restore
REM all proxy fixes (lost on Docker Desktop restart).
REM
REM Fixes applied:
REM   1. hosts.toml bind-mount:  IPv6 literal for registry-mirror
REM      (bypasses broken DNS for "registry-mirror" hostname)
REM   2. proxy-relay:  TCP relay 0.0.0.0:7892 in k8s containerd
REM      net ns -> host.docker.internal:7892 (Windows host proxy)
REM   3. /etc/hosts bind-mount: http.docker.internal -> 127.0.0.1
REM      (redirects Docker daemon proxy to relay-3128)
REM   4. proxy-relay-3128: TCP relay 127.0.0.1:3128 in Docker VM
REM      main net ns -> 192.168.65.254:7892 (fixes docker build)
REM   5. kind-registry-mirror: ensure container has socket mount
REM      and HTTPS_PROXY env (needed to reach Docker Hub)
REM ============================================================
setlocal

echo [1/7] Waiting for k8s containerd (/usr/local/bin/containerd) to start...
:wait_containerd
docker run --rm --privileged --pid=host pgvector/pgvector:pg17 sh -c "ls /proc | while read p; do if [ -f /proc/$p/comm ] && grep -q '^containerd$' /proc/$p/comm 2>/dev/null; then cmdline=$(cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' '); case \"$cmdline\" in /usr/local/bin/containerd*) echo $p; break;; esac; fi; done" > %TEMP%\cpid.txt 2>&1
set /p CPID=<%TEMP%\cpid.txt
if "%CPID%"=="" (
    echo   Not ready yet, retrying in 5s...
    ping -n 6 127.0.0.1 >nul
    goto wait_containerd
)
echo   k8s containerd PID: %CPID%

echo [2/7] Applying hosts.toml bind-mount (IPv6 literal fc00:f853:ccd:e793::3)...
docker run --rm --privileged --pid=host pgvector/pgvector:pg17 sh -c "nsenter -t %CPID% -m -- sh -c 'printf \"[host.\\\"http://[fc00:f853:ccd:e793::3]:1273\\\"]\ncapabilities = [\\\"pull\\\", \\\"resolve\\\"]\nskip_verify = true\n\" > /tmp/new_hosts.toml && mount --bind /tmp/new_hosts.toml /etc/containerd/certs.d/_default/hosts.toml && echo OK || echo FAILED'"
echo   hosts.toml: done

echo [3/7] Starting proxy-relay in k8s containerd net namespace...
docker rm -f proxy-relay 2>nul 1>nul
set MSYS_NO_PATHCONV=1
docker run -d --name proxy-relay --privileged --pid=host -v /run/desktop/mnt/host/c/code/AI/baby-talk-2/tmp/relay.pl:/relay.pl pgvector/pgvector:pg17 sh -c "nsenter -t %CPID% -n -- perl /relay.pl" >nul
set MSYS_NO_PATHCONV=
ping -n 4 127.0.0.1 >nul
docker logs proxy-relay 2>&1 | findstr /i "relay"
echo   proxy-relay: done

echo [4/7] Fixing Docker daemon proxy (/etc/hosts: http.docker.internal -> 127.0.0.1)...
docker run --rm --privileged --pid=host pgvector/pgvector:pg17 sh -c "nsenter -t 1 -m -- sh -c 'printf \"::1     localhost ip6-localhost ip6-loopback\nfe00::0 ip6-localnet\nff00::0 ip6-mcastprefix\nff02::1 ip6-allnodes\n127.0.0.1  http.docker.internal\n\" > /tmp/new_docker_hosts && mount --bind /tmp/new_docker_hosts /etc/hosts && echo OK || echo FAILED'"
echo   /etc/hosts override: done

echo [5/7] Starting proxy-relay-3128 in Docker VM main net namespace...
docker rm -f proxy-relay-3128 2>nul 1>nul
set MSYS_NO_PATHCONV=1
docker run -d --name proxy-relay-3128 --restart always --privileged --pid=host -v /run/desktop/mnt/host/c/code/AI/baby-talk-2/tmp/relay-3128.pl:/relay-3128.pl pgvector/pgvector:pg17 sh -c "while true; do nsenter -t 1 -n -- perl /relay-3128.pl; sleep 1; done" >nul
set MSYS_NO_PATHCONV=
ping -n 4 127.0.0.1 >nul
docker logs proxy-relay-3128 2>&1 | findstr /i "relay"
echo   proxy-relay-3128: done

echo [6/7] Ensuring kind-registry-mirror has socket mount + HTTPS_PROXY...
docker inspect kind-registry-mirror --format "{{range .Mounts}}{{.Source}}{{end}}" 2>nul | findstr /c:"containerd.sock" >nul
if errorlevel 1 (
    echo   Recreating kind-registry-mirror with socket mount...
    docker rm -f kind-registry-mirror 2>nul 1>nul
    set MSYS_NO_PATHCONV=1
    docker run -d --name kind-registry-mirror --network kind --restart always -v /run/containerd/containerd.sock:/run/containerd/containerd.sock --env HTTPS_PROXY=http://host.docker.internal:7892 docker/desktop-containerd-registry-mirror:v0.0.3 >nul
    set MSYS_NO_PATHCONV=
    echo   kind-registry-mirror recreated
) else (
    echo   kind-registry-mirror already has socket mount, skipping
)
docker ps --filter name=kind-registry-mirror --format "  {{.Names}}: {{.Status}}"

echo [7/7] Deploying helm charts...
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -n babytalk --create-namespace -f deploy/helm/babytalk-infra/values-kind.yaml --force-conflicts
helm upgrade --install babytalk-app deploy/helm/babytalk-app -n babytalk -f deploy/helm/babytalk-app/values-kind.yaml -f deploy/helm/babytalk-app/values-kind-secrets.yaml --force-conflicts
echo   helm: done

echo.
echo All fixes applied. Checking pod status (may take 2-3 min for redis to pull)...
kubectl -n babytalk get pods
echo.
echo Run 'kubectl -n babytalk get pods' to monitor.
endlocal
