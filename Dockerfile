# Usa imagem oficial leve baseada em Alpine (reduz superfície de ataque)
FROM node:20-alpine

# Define diretório de trabalho
WORKDIR /app

# Copia manifestos de dependências primeiro para cache eficiente
COPY app/package*.json ./

# Instala apenas dependências de produção sem arquivos extras
RUN npm ci --only=production

# Copia o código da aplicação
COPY app/ ./app/

# Aplica o princípio do menor privilégio: usa o usuário sem privilégios nativo
RUN chown -R node:node /app
USER node

# Documenta a porta da aplicação
EXPOSE 3000

# Executa o servidor Node.js
CMD ["node", "app/server.js"]
