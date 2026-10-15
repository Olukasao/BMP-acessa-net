# AcessaBMP

Instalacao isolada do [OpenBMP](https://github.com/OpenBMP/obmp-docker) nesta VM,
preparada para uso futuro pelo projeto AcessaRoute. Esta instalacao e independente
de qualquer outra aplicacao, Nginx, banco de dados ou container ja existente na VM.

## Localizacao

- Projeto: diretorio onde este repositorio foi clonado
- Dados persistentes: configurados por `OBMP_DATA_ROOT` no `.env`
- Repositorio oficial (referencia, nao editar): `source/`
  (commit `3f38af5` - "Version 2.2.3 updates")

## Estrutura

```
AcessaBMP/
├── source/           # clone oficial do obmp-docker (NAO editar diretamente)
├── config/           # reservado para configuracoes locais adicionais
├── scripts/          # start.sh, stop.sh, status.sh, logs.sh
├── backups/          # reservado para backups futuros
├── logs/             # reservado para logs locais (fora dos containers)
├── .env              # variaveis e credenciais locais (nao versionar)
├── .env.example      # modelo sem credenciais reais
├── docker-compose.yml
└── README.md

<OBMP_DATA_ROOT>/
├── config/                 # /config compartilhado entre collector e psql-app
├── kafka-data/
├── zk-data/
├── zk-log/
├── postgres/data/
├── postgres/ts/
└── grafana/
    ├── dashboards/
    └── provisioning/
```

## Diferencas em relacao ao docker-compose.yml oficial

O compose oficial (em `source/docker-compose.yml`) foi copiado e adaptado em
`docker-compose.yml`. Alteracoes feitas, e por que:

1. **Credenciais**: senha padrao `openbmp` (Postgres e Grafana) trocada por
   valores definidos em `.env` (nunca comitados). Use senhas fortes e unicas.
2. **Exposicao de rede**: Kafka (9092), PostgreSQL (5432), psql-app (9005) e
   whois (4300) publicam somente em `127.0.0.1`. Grafana (3000) tambem usa
   `127.0.0.1` por padrao; `GRAFANA_BIND_IP` permite escolher uma interface
   especifica quando o acesso pela LAN for necessario.
3. **Porta 5000 (BMP/Collector)**: mantida publicada em todas as interfaces
   (`0.0.0.0:5000`), pois e o objetivo futuro do projeto: receber BMP dos
   roteadores de borda pela rede. Restrinja o acesso a essa porta via firewall
   aos IPs dos roteadores autorizados.
4. **Grafana**: acesso anonimo (`GF_AUTH_ANONYMOUS_ENABLED`) desabilitado.
   A porta e vinculada a `127.0.0.1` por padrao. Para acesso pela LAN, defina
   `GRAFANA_BIND_IP` no `.env` para o endereco da interface desejada e limite
   o acesso usando firewall.

## Permissoes dos volumes (UID/GID por container)

Nao foi usado `chmod 777`/`7777` (diferente da sugestao no README oficial).
Em vez disso, identificamos o UID de cada imagem e aplicamos apenas o necessario:

| Container         | Roda como   | Precisa de ajuste? |
|--------------------|-------------|---------------------|
| obmp-psql          | uid 1000    | Nao (mesmo uid do proprietario das pastas) |
| obmp-kafka         | uid 1000    | Nao |
| obmp-zookeeper     | uid 1000    | Nao |
| obmp-collector     | root        | Nao (root escreve em qualquer lugar) |
| obmp-psql-app      | root        | Nao |
| obmp-grafana       | uid 472     | Sim: `grafana` e `grafana/provisioning` em `OBMP_DATA_ROOT` tem chown 472:472 |

Nao existe (nem e necessario) o arquivo `init_db` mencionado no README oficial.
O container `psql-app` usa a logica inversa: ele inicializa o schema
automaticamente na primeira execucao e cria `/config/do_not_init_db` para
nunca mais reinicializar. **NAO apague esse arquivo em producao**, ou o schema
sera recarregado.

## Uso

```bash
cd /path/to/AcessaBMP

cp .env.example .env  # edite .env e substitua todos os valores de exemplo
./scripts/start.sh     # sobe os containers (docker compose up -d)
./scripts/stop.sh       # para os containers SEM remover volumes/dados (docker compose stop)
./scripts/status.sh     # mostra containers, portas e uso de disco/recursos
./scripts/logs.sh       # segue os logs de todos os servicos
```

> Nota: o usuario que executa os comandos precisa ter permissao para usar Docker.
> Se necessario, use `sudo` antes dos comandos `docker`/`docker compose`.

**Nunca use `docker compose down -v`** neste projeto — isso apagaria os volumes
de dados. Os scripts fornecidos usam apenas `stop`/`up -d`.

## BMP

```
TCP 5000
```

Ainda não existe nenhum roteador enviando BMP para esta porta. O Collector já
está no ar e aguardando conexões ("Ready. Waiting for connections" nos logs),
mas nenhuma sessão BMP existe até que um roteador seja configurado.

### Próximo passo futuro (NÃO executado nesta instalação)

Configurar o roteador de borda da AcessaNet para enviar BMP para:

```
<IP_DA_VM>:5000
```

## Servicos e portas

| Servico     | Container         | Porta interna | Publicada em      |
|-------------|--------------------|----------------|---------------------|
| Collector   | obmp-collector     | 5000           | `0.0.0.0:5000`      |
| Kafka       | obmp-kafka         | 9092           | `127.0.0.1:9092`    |
| Zookeeper   | obmp-zookeeper     | 2181           | (nao publicada)     |
| PostgreSQL  | obmp-psql          | 5432           | `127.0.0.1:5432`    |
| PSQL App    | obmp-psql-app      | 9005           | `127.0.0.1:9005`    |
| Grafana     | obmp-grafana       | 3000           | `127.0.0.1:3000` por padrao |
| Whois       | obmp-whois         | 43             | `127.0.0.1:4300`    |

## Grafana

Acesso: `http://127.0.0.1:3000` por padrao. Para acesso pela LAN, configure
`GRAFANA_BIND_IP` no `.env` para o endereco da interface escolhida e ajuste o
firewall. Login anonimo e signup desabilitados (`GF_AUTH_ANONYMOUS_ENABLED=false`,
`GF_USERS_ALLOW_SIGN_UP=false`). Usuario administrativo: `admin` (senha em `.env`).

Dashboard inicial `AcessaBMP - Overview` (uid `obmp-home`, home page padrao)
mostra: routers, peers, prefixos ativos, ultima atualizacao, e tabelas de
routers/peers registrados. Enquanto nenhum roteador estiver enviando BMP,
os valores ficam zerados normalmente (nao e uma falha).

### Datasource "OpenBMP"

Provisionado via `<OBMP_DATA_ROOT>/grafana/provisioning/datasources/openbmp.yml`,
conectando ao `obmp-psql:5432` pela rede Docker `acessabmp_default` (mesma
rede dos demais containers OpenBMP — o Grafana nao precisou de rede externa
adicional pois ja fazia parte do mesmo compose). Conexao usa `sslmode=require`.

Usuario do banco: `grafana_reader`, criado com privilegios **somente leitura**
(`CONNECT`, `USAGE` no schema `public`, `SELECT` em todas as tabelas). Sem
INSERT/UPDATE/DELETE/CREATE/DROP/ALTER. Senha em `.env`,
variavel `GRAFANA_READER_PASSWORD` (injetada no container Grafana como
`OPENBMP_GRAFANA_DB_PASSWORD`, referenciada no provisioning via `$OPENBMP_GRAFANA_DB_PASSWORD`).

Para validar a conexao (via API, sem expor senha):

```bash
GF_USER=$(sudo grep '^GF_ADMIN_USER=' .env | cut -d= -f2)
GF_PASS=$(sudo grep '^GF_ADMIN_PASSWORD=' .env | cut -d= -f2)
GRAFANA_BIND_IP=$(sudo grep '^GRAFANA_BIND_IP=' .env | cut -d= -f2)
GF_URL="http://${GRAFANA_BIND_IP:-127.0.0.1}:3000"
curl -s -u "${GF_USER}:${GF_PASS}" -X POST "${GF_URL}/api/ds/query" \
  -H "Content-Type: application/json" \
  -d '{"queries":[{"refId":"A","datasource":{"type":"postgres","uid":"openbmp"},"rawSql":"SELECT 1","format":"table"}]}'
```

### Dashboards provisionados

Apenas o dashboard proprio `AcessaBMP - Overview` (criado nesta instalacao).
Nao foram encontrados dashboards Grafana oficiais compatíveis no clone em
`source/` do obmp-docker (nenhum `.json` de dashboard no repositorio oficial
nesse commit).

### Backup do Grafana

Dados persistentes em `<OBMP_DATA_ROOT>/grafana` (SQLite interno + provisioning).
Para backup a frio (containers parados, sem afetar OpenBMP):

```bash
sudo ./scripts/stop.sh   # ou: docker compose stop grafana (sem afetar os demais)
OBMP_DATA_ROOT=$(grep '^OBMP_DATA_ROOT=' .env | cut -d= -f2)
sudo tar -czf backups/grafana-$(date +%Y%m%d).tar.gz -C "$OBMP_DATA_ROOT" grafana
sudo ./scripts/start.sh
```

Nunca use `docker compose down -v` — isso apagaria os volumes de dados.

## Credenciais

Guardadas somente em `.env` (permissao 600). Nao estao
documentadas aqui nem em nenhum outro lugar em texto pleno. Inclui agora
tambem `GRAFANA_READER_PASSWORD` (usuario read-only `grafana_reader` no
PostgreSQL, usado exclusivamente pelo datasource do Grafana).

## Observacoes de seguranca conhecidas (heranca do projeto oficial)

- O container `obmp-psql` roda com `privileged: true` no compose oficial
  (necessario para os `sysctls` de tcp_keepalive usados pelo TimescaleDB/Patroni).
  Isso nao foi alterado nesta instalacao.
- Configure o firewall do host para restringir a porta 5000 aos IPs dos
  roteadores autorizados. Nenhuma regra de firewall e criada automaticamente.
