# Dashboard de Monitoramento - FIAP Hack

Este dashboard para monitorar as métricas essenciais do sistema FIAP Hack, incluindo performance da API e processamento de vídeos.

## Como Importar o Dashboard

1. Link de acesso: `http://addf2b00664f84e3497d670efebb13bd-1698710732.us-east-1.elb.amazonaws.com`
2. Faça login com as credenciais:
   - **Usuário**: `admin`
   - **Senha**: `admin123`
3. Clique no ícone "+" no menu lateral
4. Selecione "Import"
5. Clique em "Upload JSON file"
6. Selecione o arquivo `dashboard-fiap-hack.json`
7. Clique em "Import"

## Métricas Monitoradas

### 📊 Performance da API

#### 1. **Taxa de Requisições HTTP**
- **Métrica**: `rate(http_requests_total[5m])`
- **Descrição**: Número de requisições por segundo
- **Importância**: Monitora o volume de tráfego da aplicação

#### 2. **Latência Média das Requisições**
- **Métrica**: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])`
- **Descrição**: Tempo médio de resposta das requisições
- **Importância**: Identifica problemas de performance

#### 3. **Taxa de Erros 5xx (Erros do Servidor)**
- **Métrica**: `sum(rate(http_requests_total{status=~"5.."}[5m]))`
- **Descrição**: Requisições que resultaram em erro do servidor
- **Importância**: Alerta para problemas internos da aplicação

#### 4. **Taxa de Erros 4xx (Erros do Cliente)**
- **Métrica**: `sum(rate(http_requests_total{status=~"4.."}[5m]))`
- **Descrição**: Requisições com erro do cliente (404, 400, etc.)
- **Importância**: Identifica problemas de validação ou recursos não encontrados

#### 5. **Taxa de Sucessos 2xx**
- **Métrica**: `sum(rate(http_requests_total{status=~"2.."}[5m]))`
- **Descrição**: Requisições bem-sucedidas
- **Importância**: Monitora a saúde geral da aplicação

### 🎥 Processamento de Vídeo

#### 6. **Total de Jobs Processados**
- **Métrica**: `jobs_processing_total`
- **Descrição**: Número total de jobs de processamento de vídeo
- **Importância**: Acompanha o volume de trabalho processado

#### 7. **Duração Média do Processamento de Vídeo**
- **Métrica**: `rate(video_processing_duration_seconds_sum[5m]) / rate(video_processing_duration_seconds_count[5m])`
- **Descrição**: Tempo médio para processar um vídeo
- **Importância**: Identifica gargalos no processamento

#### 8. **Taxa de Processamento de Vídeos**
- **Métrica**: `rate(video_processing_duration_seconds_count[5m])`
- **Descrição**: Número de vídeos processados por segundo
- **Importância**: Monitora a capacidade de processamento

## Alertas Recomendados

### Alertas Críticos
- **Latência > 5s**: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]) > 5`
- **Taxa de Erro 5xx > 5%**: `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.05`
- **Duração de Processamento > 10min**: `rate(video_processing_duration_seconds_sum[5m]) / rate(video_processing_duration_seconds_count[5m]) > 600`

### Alertas de Aviso
- **Latência > 2s**: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]) > 2`
- **Taxa de Erro 4xx > 10%**: `sum(rate(http_requests_total{status=~"4.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.1`

## Métricas Adicionais Recomendadas

### Para Implementação Futura

#### Métricas de Infraestrutura
- **CPU Usage**: `rate(container_cpu_usage_seconds_total[5m])`
- **Memory Usage**: `container_memory_usage_bytes`
- **Disk Usage**: `container_fs_usage_bytes`

#### Métricas de Negócio
- **Uploads por Usuário**: Contador de uploads por usuário
- **Tamanho Médio dos Vídeos**: `video_file_size_bytes`
- **Taxa de Conversão**: Vídeos processados vs. enviados

#### Métricas de Fila
- **Jobs na Fila**: `queue_size`
- **Tempo na Fila**: `queue_wait_time_seconds`

## Configuração do Refresh

O dashboard está configurado para atualizar a cada **5 segundos** e mostrar dados das **últimas 2 horas**. Você pode ajustar esses valores conforme necessário.