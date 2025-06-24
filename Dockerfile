# --- Stage 1: Dependencies and Build ---
FROM node:20-alpine AS builder

WORKDIR /app

# 1. Copy package.json and package-lock.json first to leverage Docker cache
COPY package*.json ./

# 2. Install all dependencies (including dev dependencies for build tools like Prisma)
RUN npm install

# 3. Copy Prisma schema
COPY prisma ./prisma/

# 4. Generate Prisma client (must be done after npm install)
RUN npx prisma generate

# 5. Copy the rest of your application source code
COPY . .

# 6. Build the NestJS application
RUN npm run build


# --- Stage 2: Production Runtime ---
FROM node:20-alpine

WORKDIR /app

# Instalar bash para compatibilidade com wait-for-it.sh
# Isso aumentará ligeiramente o tamanho da imagem final.
RUN apk add --no-cache bash

# 1. Copy wait-for-it.sh for database readiness check (if needed)
# Certifique-se de que o arquivo wait-for-it.sh está na raiz da pasta do seu backend
COPY wait-for-it.sh /usr/local/bin/wait-for-it.sh
RUN chmod +x /usr/local/bin/wait-for-it.sh


# 2. Copy only production dependencies from builder stage
COPY --from=builder /app/package*.json ./
# 3. Install only production dependencies (this will install @prisma/client, bcrypt, etc.)
RUN npm install --production

# 4. Copy the built application code from the builder stage's dist folder
COPY --from=builder /app/dist ./dist

# 5. Copy the generated Prisma client from the builder stage
# This ensures that the generated client and its binaries are available in the final image
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client


# 6. Expose the port your NestJS application listens on (default is 3000)
EXPOSE 3000

# 7. Command to run the NestJS application in production mode
# Use wait-for-it.sh to ensure DB is up before starting backend
CMD ["bash", "/usr/local/bin/wait-for-it.sh", "mysql_db:3306", "--", "node", "dist/main"]