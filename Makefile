APP := 'no-app'

ANSI_RESET := \e[0m
ANSI_YELLOW := \e[0;33m
ANSI_GREEN := \033[32m

SUCCESS := $(ANSI_GREEN) ✔$(ANSI_RESET)

SERVICE := $(word 2, $(MAKECMDGOALS))
ifeq ($(SERVICE),)
	SERVICE = "app"
endif

SHELL_COMMAND := $(wordlist 3, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
MIGRATOR_SUBCOMMANDS := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))


help:
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) install"
	@echo "    Fetch, build and create initial infrastructure of the app"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) git"
	@echo "    Update code of the app and its submodules"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) network"
	@echo "    Create a shared network"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) env"
	@echo "    Create .env files from examples"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) build"
	@echo "    Build the docker image"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) up"
	@echo "    Bring up the containers"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) down"
	@echo "    Stop the containers"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) reup"
	@echo "    Restart the containers"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) deploy"
	@echo "    Build the docker image and restart the container"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) shell <service>"
	@echo "    Open a shell in the container"
	@echo ""
	@echo "$(ANSI_YELLOW)make$(ANSI_RESET) logs <service>"
	@echo "    Open and follow logs of the container"
	@echo ""


install:
	@make git
	@make network
	@make env
	@make up


git:
	@git fetch && git pull && git submodule update --init --recursive --remote


network:
	@docker network create motivatr-shared-network
	@echo "$(SUCCESS) network motivatr-shared-network has been created"


env:
	@for file in ./deploy/.*.example; do \
		copied="$${file%.example}"; \
		[ -e "$$copied" ] || cp "$$file" "$$copied"; \
	done


up:
	@docker compose -f ./deploy/docker-compose.yml up -d --build


down:
	@docker compose -f ./deploy/docker-compose.yml down


logs:
	@docker logs motivatr-$(APP)-$(SERVICE) -f


shell:
ifeq ($(SHELL_COMMAND),)
	@docker exec -it motivatr-$(APP)-$(SERVICE) bash
else
	@docker exec -it motivatr-$(APP)-$(SERVICE) bash -c "$(SHELL_COMMAND)"
endif


migrator:
	@if [ ! -d "./motivatr-tool-migrator" ]; then \
		echo "The motivatr-tool-migrator submodule is not found"; \
		exit 1; \
	fi
	@docker build . \
		--quiet \
		--tag motivatr-migrator-image:latest \
		--file ./motivatr-tool-migrator/deploy/Dockerfile \
		>/dev/null
	@docker rm -f motivatr-migrator >/dev/null 2>&1
	@docker run \
		--name motivatr-migrator \
		--env-file ./deploy/.env.db \
		--network=motivatr-shared-network \
		motivatr-migrator-image:latest \
		./migrator $(MIGRATOR_SUBCOMMANDS)