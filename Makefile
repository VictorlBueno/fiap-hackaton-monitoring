.PHONY: help deploy-all deploy-prometheus deploy-grafana status logs-all port-forward-grafana init-all plan-all apply-all destroy-all backup-state restore-state clean-state

# Configurações do projeto
PROJECT_NAME = fiap-hack
ENVIRONMENT = production
BUCKET_NAME = fiap-hack-terraform-state
AWS_REGION = us-east-1

help: ## Mostra esta ajuda
	@echo "🔍 Sistema de Monitoramento - Prometheus + Grafana"
	@echo ""
	@echo "📋 Comandos disponíveis:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init-all: ## Inicializa todos os módulos Terraform
	@echo "🔧 Inicializando módulos Terraform..."
	@echo "📊 Inicializando Prometheus..."
	cd terraform/prometheus && terraform init
	@echo "📈 Inicializando Grafana..."
	cd terraform/grafana && terraform init
	@echo "✅ Inicialização concluída!"

plan-all: ## Executa plan em todos os módulos
	@echo "📋 Executando plan em todos os módulos..."
	@echo "📊 Plan do Prometheus:"
	cd terraform/prometheus && terraform plan
	@echo ""
	@echo "📈 Plan do Grafana:"
	cd terraform/grafana && terraform plan

apply-all: ## Aplica mudanças em todos os módulos
	@echo "🚀 Aplicando mudanças em todos os módulos..."
	@echo "📊 Aplicando Prometheus..."
	cd terraform/prometheus && terraform apply -auto-approve
	@echo "📈 Aplicando Grafana..."
	cd terraform/grafana && terraform apply -auto-approve
	@echo "✅ Aplicação concluída!"

deploy-all: init-all apply-all ## Deploy completo do sistema de monitoramento
	@echo "✅ Deploy completo finalizado!"
	@echo ""
	@echo "🌐 Para acessar o Grafana:"
	@echo "   make get-grafana-url"

deploy-prometheus: ## Deploy apenas do Prometheus
	@echo "📊 Deploy do Prometheus..."
	cd terraform/prometheus && terraform init
	cd terraform/prometheus && terraform apply -auto-approve
	@echo "✅ Prometheus deployado!"

deploy-grafana: ## Deploy apenas do Grafana
	@echo "📈 Deploy do Grafana..."
	cd terraform/grafana && terraform init
	cd terraform/grafana && terraform apply -auto-approve
	@echo "✅ Grafana deployado!"

status: ## Status dos componentes de monitoramento
	@echo "📊 Status do sistema de monitoramento:"
	@echo ""
	@echo "🔍 Prometheus:"
	kubectl get pods -n monitoring -l app=prometheus
	@echo ""
	@echo "📈 Grafana:"
	kubectl get pods -n monitoring -l app=grafana
	@echo ""
	@echo "🌐 Services:"
	kubectl get svc -n monitoring
	@echo ""
	@echo "💾 PVCs:"
	kubectl get pvc -n monitoring

logs-all: ## Logs de todos os componentes
	@echo "📋 Logs do sistema de monitoramento:"
	@echo ""
	@echo "🔍 Logs do Prometheus:"
	kubectl logs -f deployment/prometheus -n monitoring --tail=50
	@echo ""
	@echo "📈 Logs do Grafana:"
	kubectl logs -f deployment/grafana -n monitoring --tail=50

logs-prometheus: ## Logs do Prometheus
	@echo "🔍 Logs do Prometheus:"
	kubectl logs -f deployment/prometheus -n monitoring

logs-grafana: ## Logs do Grafana
	@echo "📈 Logs do Grafana:"
	kubectl logs -f deployment/grafana -n monitoring

get-grafana-url: ## Obtém a URL de acesso ao Grafana
	@echo "🌐 URL do Grafana:"
	@kubectl get svc grafana-service -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "LoadBalancer ainda não está pronto"
	@echo ""
	@echo "🔑 Credenciais: admin/admin123"

port-forward-grafana: ## Port-forward para Grafana (desenvolvimento)
	@echo "🌐 Port-forward para Grafana..."
	@echo "Acesse: http://localhost:3000"
	@echo "Credenciais: admin/admin123"
	kubectl port-forward svc/grafana-service 3000:80 -n monitoring

port-forward-prometheus: ## Port-forward para Prometheus (desenvolvimento)
	@echo "🔍 Port-forward para Prometheus..."
	@echo "Acesse: http://localhost:9090"
	kubectl port-forward svc/prometheus-service 9090:9090 -n monitoring

test-connectivity: ## Testa conectividade dos componentes
	@echo "🔍 Testando conectividade..."
	@echo ""
	@echo "1️⃣ Testando Prometheus..."
	kubectl exec -n monitoring deployment/prometheus -- wget -qO- http://localhost:9090/-/healthy || echo "❌ Prometheus não está saudável"
	@echo ""
	@echo "2️⃣ Testando Grafana..."
	kubectl exec -n monitoring deployment/grafana -- wget -qO- http://localhost:3000/api/health || echo "❌ Grafana não está saudável"
	@echo ""
	@echo "3️⃣ Testando métricas da aplicação..."
	kubectl exec -n video-processor deployment/video-processor -- wget -qO- http://localhost:8080/metrics || echo "❌ Endpoint de métricas não está disponível"

backup-state: ## Faz backup dos estados Terraform
	@echo "💾 Fazendo backup dos estados Terraform..."
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@echo "📊 Backup do estado do Prometheus..."
	aws s3 cp s3://$(BUCKET_NAME)/monitoring/prometheus/terraform.tfstate backups/$(shell date +%Y%m%d_%H%M%S)/prometheus.tfstate --region $(AWS_REGION)
	@echo "📈 Backup do estado do Grafana..."
	aws s3 cp s3://$(BUCKET_NAME)/monitoring/grafana/terraform.tfstate backups/$(shell date +%Y%m%d_%H%M%S)/grafana.tfstate --region $(AWS_REGION)
	@echo "✅ Backup concluído em backups/$(shell date +%Y%m%d_%H%M%S)/"

restore-state: ## Restaura estados Terraform de um backup
	@echo "🔄 Restaurando estados Terraform..."
	@if [ -z "$(BACKUP_DIR)" ]; then \
		echo "❌ Especifique o diretório de backup: make restore-state BACKUP_DIR=backups/YYYYMMDD_HHMMSS"; \
		exit 1; \
	fi
	@echo "📊 Restaurando estado do Prometheus..."
	aws s3 cp $(BACKUP_DIR)/prometheus.tfstate s3://$(BUCKET_NAME)/monitoring/prometheus/terraform.tfstate --region $(AWS_REGION)
	@echo "📈 Restaurando estado do Grafana..."
	aws s3 cp $(BACKUP_DIR)/grafana.tfstate s3://$(BUCKET_NAME)/monitoring/grafana/terraform.tfstate --region $(AWS_REGION)
	@echo "✅ Restauração concluída!"

destroy-all: ## Destroi todo o sistema de monitoramento
	@echo "⚠️  ATENÇÃO: Isso irá destruir todo o sistema de monitoramento!"
	@read -p "Confirma a destruição? (digite 'sim' para confirmar): " confirm; \
	if [ "$$confirm" = "sim" ]; then \
		echo "🗑️ Destruindo sistema de monitoramento..."; \
		cd terraform/grafana && terraform destroy -auto-approve; \
		cd ../prometheus && terraform destroy -auto-approve; \
		echo "✅ Sistema de monitoramento destruído!"; \
	else \
		echo "❌ Operação cancelada."; \
	fi

clean: ## Limpa arquivos temporários
	@echo "🧹 Limpando arquivos temporários..."
	find . -name "*.tfstate*" -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "✅ Limpeza concluída!"

clean-state: ## Limpa estados locais (mantém no S3)
	@echo "🧹 Limpando estados locais..."
	cd terraform/prometheus && rm -f *.tfstate*
	cd terraform/grafana && rm -f *.tfstate*
	@echo "✅ Estados locais removidos!"

validate-all: ## Valida todos os módulos Terraform
	@echo "✅ Validando módulos Terraform..."
	@echo "📊 Validando Prometheus..."
	cd terraform/prometheus && terraform validate
	@echo "📈 Validando Grafana..."
	cd terraform/grafana && terraform validate
	@echo "✅ Validação concluída!"

fmt-all: ## Formata todos os arquivos Terraform
	@echo "🎨 Formatando arquivos Terraform..."
	@echo "📊 Formatando Prometheus..."
	cd terraform/prometheus && terraform fmt -recursive
	@echo "📈 Formatando Grafana..."
	cd terraform/grafana && terraform fmt -recursive
	@echo "✅ Formatação concluída!"

show-outputs: ## Mostra outputs de todos os módulos
	@echo "📊 Outputs do Prometheus:"
	cd terraform/prometheus && terraform output
	@echo ""
	@echo "📈 Outputs do Grafana:"
	cd terraform/grafana && terraform output 