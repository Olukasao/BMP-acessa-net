<div align="center">

# BGP Timeline

**Infraestrutura de monitoramento BGP com histórico de rotas.**
Coleta rotas direto dos roteadores via BMP e guarda tudo em um banco consultável.

![BGP](https://img.shields.io/badge/BGP-monitoring-0A66C2)
![BMP](https://img.shields.io/badge/BMP-RFC%207854-informational)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-TimescaleDB-4169E1?logo=postgresql&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-dashboards-F46800?logo=grafana&logoColor=white)

</div>

---

## O que é

Uma implantação **isolada e endurecida do [OpenBMP](https://github.com/OpenBMP/obmp-docker)** para acompanhar o comportamento das rotas BGP de uma rede. Os roteadores de borda enviam suas tabelas e atualizações pelo protocolo **BMP** (BGP Monitoring Protocol, [RFC 7854](https://www.rfc-editor.org/rfc/rfc7854)), e o sistema armazena o estado atual e o histórico das atualizações recebidas em PostgreSQL, com visualização no Grafana.

Serve de base para responder, por consulta ou painel, perguntas como *"quais prefixos estão ativos?"*, *"por qual caminho de AS eles chegam?"* e *"o que mudou, e quando?"*.

> **Não é um app web escrito do zero.** O coletor, o banco e o processamento vêm do OpenBMP, projeto da Cisco. O trabalho deste repositório está na **implantação, na configuração segura e na operação**, descritas abaixo.

## O que foi feito neste repositório

O compose oficial do OpenBMP foi copiado e adaptado. As diferenças:

| Tema | Mudança |
|---|---|
| **Credenciais** | A senha padrão `openbmp` saiu. Banco e Grafana usam segredos definidos em `.env`, que nunca é versionado. |
| **Exposição de rede** | Kafka, PostgreSQL, API e whois só escutam em `127.0.0.1`. A única porta pública é a `5000`, que recebe o BMP dos roteadores. |
| **Grafana** | Acesso anônimo e cadastro de usuários desligados. Escuta só em `127.0.0.1`, com a interface configurável por variável. |
| **Banco** | O Grafana lê por um usuário **somente leitura** (`grafana_reader`), com `sslmode=require`. |
| **Permissões** | Em vez do `chmod 777` sugerido no projeto oficial, cada container recebe apenas a permissão de que precisa (mapeamento de UID por serviço). |
| **Dados** | Todos os dados persistentes ficam fora do repositório, em um caminho configurável (`OBMP_DATA_ROOT`). |
| **Operação** | Scripts de `start`, `stop`, `status` e `logs`, desenhados para **nunca** apagar volumes. |
| **Painel** | Dashboard próprio provisionado automaticamente: roteadores, peers, prefixos ativos e última atualização. |

## Arquitetura

```text
roteadores de borda
        │  BMP (TCP 5000)
        ▼
  ┌───────────┐    ┌───────┐    ┌─────────────────┐    ┌─────────────────────┐
  │ Collector │───►│ Kafka │───►│ psql-app        │───►│ PostgreSQL          │
  │ (OpenBMP) │    │ + ZK  │    │ (grava rotas e  │    │ (TimescaleDB)       │
  └───────────┘    └───────┘    │  histórico)     │    └──────────┬──────────┘
                                └─────────────────┘               │ somente leitura
                                                                  ▼
                                                            ┌───────────┐
                                                            │  Grafana  │
                                                            └───────────┘
```

| Serviço | Função |
|---|---|
| **Collector** | Recebe as sessões BMP dos roteadores. |
| **Kafka e Zookeeper** | Fila entre a coleta e o processamento. |
| **psql-app** | Consome a fila e grava rotas, peers e atualizações. |
| **PostgreSQL** | Armazena o estado e o histórico. |
| **Grafana** | Painéis de consulta. |
| **whois** | Consulta de informações de prefixos e AS. |

## Como rodar

Requer Docker com o Compose.

```bash
git clone https://github.com/Olukasao/bgp-timeline.git
cd bgp-timeline

cp .env.example .env      # edite e troque todos os valores de exemplo
./scripts/start.sh        # sobe os containers
./scripts/status.sh       # containers, portas e uso de recursos
./scripts/logs.sh         # acompanha os logs
./scripts/stop.sh         # para sem apagar dados
```

Abra o Grafana em `http://127.0.0.1:3000` (usuário e senha do `.env`).

Depois, configure o roteador de borda para enviar BMP para `<IP_DA_VM>:5000`. Enquanto nenhum roteador estiver enviando, o coletor aguarda conexões e os painéis ficam zerados, o que é normal.

> **Nunca rode `docker compose down -v`**: isso apagaria os volumes de dados. Os scripts usam só `stop` e `up -d`.

## Segurança

- Segredos só no `.env` (permissão 600), fora do Git.
- Serviços internos presos em `127.0.0.1`.
- **Restrinja a porta 5000 por firewall** aos IPs dos roteadores autorizados. Nenhuma regra é criada automaticamente.
- O container do PostgreSQL roda com `privileged: true`, herança do projeto oficial (necessário para ajustes de `sysctl`). Isso não foi alterado.
- Dados de rotas e topologia reais ficam no banco local e **não** pertencem a este repositório.

## Estado do projeto

- Pilha OpenBMP implantada e funcionando, com Grafana e painel inicial.
- Nenhuma sessão BMP configurada nos roteadores no momento da documentação.
- **Próximos passos:** conectar os roteadores de borda, criar painéis de **histórico de mudanças de rota** sobre os dados já gravados e uma interface web própria para visualização.

## Documentação

Detalhes de implantação (diferenças em relação ao compose oficial, permissões dos volumes, portas, Grafana e backup): [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Créditos e licença

Baseado no [OpenBMP](https://github.com/OpenBMP/obmp-docker), da Cisco Systems, distribuído sob licença **BSD de 3 cláusulas**. O texto original está em [source/LICENSE](source/LICENSE), e a cópia do projeto oficial em `source/` não foi modificada. Ao redistribuir, mantenha o aviso de direitos autorais e os termos dessa licença.
