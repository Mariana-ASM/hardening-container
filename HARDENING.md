# Relatório de Hardening de Containers

## 1. Problemas Encontrados na Configuração Inicial

- **Credenciais em código aberto:** A senha `ENV DB_PASSWORD=123456` estava gravada diretamente na camada do Dockerfile e `MYSQL_ROOT_PASSWORD: root` no Docker Compose.
- **Execução como Root:** A aplicação não definia usuário, rodando como administrador (UID 0), facilitando técnicas de container breakout.
- **Imagem base inadequada e pesada:** Uso de `apt-get install nodejs npm`, aumentando drasticamente a superfície de ataque com pacotes desnecessários.
- **Exposição externa desnecessária de banco de dados:** A porta `3306` estava mapeada diretamente para o host, quando apenas o serviço da aplicação web precisava se comunicar com o MySQL.
- **Ausência de limites de recursos:** Sem limites de CPU e memória, tornando o ambiente hospedeiro vulnerável a negação de serviço (DoS).
- **Sistema de arquivos totalmente gravável:** O container permitia escrita em qualquer diretório raiz em tempo de execução.

## 2. Medidas Aplicadas

- **Adoção de imagem minimalista e usuário restrito:** Migração para `node:20-alpine` e uso do usuário sem privilégios `USER node`.
- **Gerenciamento de segredos com .env:** Credenciais retiradas do código e lidas via variáveis de ambiente (`.env`), bloqueadas via `.gitignore` e documentadas no `.env.example`.
- **Isolamento de rede:** Remoção do mapeamento da porta 3306 para a máquina hospedeira, restringindo a comunicação do banco estritamente à `rede_interna`.
- **Contenção do sistema e kernel:** Ativação de `read_only: true`, remoção total de capabilities (`cap_drop: ALL`) e prevenção contra elevação de privilégios (`no-new-privileges:true`).
- **Cotas de recursos:** Definição de limites estritos de CPU (0.50 e 0.75) e memória (256MB e 512MB) para ambos os serviços.

## 3. Análise Final

1. **Qual era o principal risco encontrado no projeto?**
   A combinação de execução com usuário root, credenciais expostas em texto limpo e porta do banco aberta externamente para a rede física.

2. **Qual alteração de hardening foi mais importante? Por quê?**
   A mudança de privilégios para usuário não-root (`USER node`). Se a aplicação sofrer um ataque de Remote Code Execution (RCE), o atacante não terá privilégios de administrador para comprometer o container ou escapar para o host.

3. **O que poderia acontecer caso o container da aplicação fosse comprometido?**
   Sem o hardening, o atacante poderia instalar ferramentas adicionais (devido ao sistema de arquivos gravável), tentar explorar o kernel do host como root e acessar o banco de dados desprotegido.

4. **Como o princípio do menor privilégio foi aplicado?**
   Foi aplicado removendo todas as capabilities desnecessárias do Linux kernel (`cap_drop: ALL`), tornando o sistema de arquivos apenas leitura (`read_only`), bloqueando novos privilégios e mantendo a porta do banco fechada para fora.

5. **Por que o .env não deve ser enviado para o repositório?**
   Repositórios Git mantêm histórico permanente. Commitar segredos expõe as credenciais a qualquer pessoa com acesso ao código, facilitando invasões em ambientes produtivos.

6. **Qual é a função do .env.example?**
   Atuar como documentação de contrato para a equipe de desenvolvimento, informando quais chaves e variáveis a aplicação necessita para funcionar, sem expor os valores sensíveis reais.

7. **Como o projeto poderia receber novas verificações de segurança automaticamente em uma pipeline CI/CD?**
   Através de linters de Dockerfile (`hadolint`), scanners de vulnerabilidades de imagens (`Trivy` ou `Grype`) e detectores de segredos em código (`Gitleaks`).

8. **Quais medidas adicionais poderiam ser aplicadas caso essa aplicação fosse executada em Kubernetes?**
   Definição de `SecurityContext` restrito (`runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`), uso de `NetworkPolicies` para restringir comunicação entre pods e uso de *Secrets* gerenciados de forma criptografada.
