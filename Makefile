DOCKER ?= docker
CGROUP_ROOT ?= /sys/fs/cgroup
NGINX_PORT ?= 8080

IDLE_CONTAINER := zidle-idle
NGINX_CONTAINER := zidle-nginx
CPU_CONTAINER := zidle-cpu
CONTAINERS := $(IDLE_CONTAINER) $(NGINX_CONTAINER) $(CPU_CONTAINER)

.PHONY: help up-testcontainers down-testcontainers restart-testcontainers show-testcontainers curl-nginx

help:
	@echo "Targets:"
	@echo "  make up-testcontainers       Start sample Docker containers"
	@echo "  make down-testcontainers     Remove sample Docker containers"
	@echo "  make restart-testcontainers  Recreate sample Docker containers"
	@echo "  make show-testcontainers     Show PID, cgroup path, and cpu.stat"
	@echo "  make curl-nginx              Send one request to the sample nginx"
	@echo ""
	@echo "Variables:"
	@echo "  CGROUP_ROOT=$(CGROUP_ROOT)"
	@echo "  NGINX_PORT=$(NGINX_PORT)"

up-testcontainers:
	@echo "Starting zidle sample containers..."
	@$(DOCKER) rm -f $(CONTAINERS) >/dev/null 2>&1 || true
	$(DOCKER) run --rm -d --name $(IDLE_CONTAINER) busybox sleep 1d
	$(DOCKER) run --rm -d --name $(NGINX_CONTAINER) -p $(NGINX_PORT):80 nginx:alpine
	$(DOCKER) run --rm -d --name $(CPU_CONTAINER) --cpus=0.25 alpine sh -c 'while true; do :; done'
	@echo ""
	@echo "Run 'make show-testcontainers' to inspect their cgroups."

down-testcontainers:
	@echo "Removing zidle sample containers..."
	@$(DOCKER) rm -f $(CONTAINERS) >/dev/null 2>&1 || true

restart-testcontainers: down-testcontainers up-testcontainers

show-testcontainers:
	@for c in $(CONTAINERS); do \
		if ! $(DOCKER) inspect "$$c" >/dev/null 2>&1; then \
			echo "container=$$c not running"; \
			echo; \
			continue; \
		fi; \
		pid=$$($(DOCKER) inspect -f '{{.State.Pid}}' "$$c"); \
		cg=$$(cut -d: -f3 /proc/$$pid/cgroup); \
		echo "container=$$c"; \
		echo "pid=$$pid"; \
		echo "cgroup=$$cg"; \
		echo "cpu.stat:"; \
		if [ -f "$(CGROUP_ROOT)$$cg/cpu.stat" ]; then \
			sed 's/^/  /' "$(CGROUP_ROOT)$$cg/cpu.stat"; \
		else \
			echo "  missing: $(CGROUP_ROOT)$$cg/cpu.stat"; \
		fi; \
		echo; \
	done

curl-nginx:
	curl -fsS http://localhost:$(NGINX_PORT)/ >/dev/null
	@echo "sent one request to nginx on port $(NGINX_PORT)"
