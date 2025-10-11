# Dockerfile
FROM node:18-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --production

COPY . .

EXPOSE 3002

ENV NODE_ENV=production
ENV DB_HOST=localhost
ENV DB_USER=root
ENV DB_PASSWORD=password
ENV DB_NAME=inventario
ENV DB_PORT=3306
ENV JWT_SECRET=change-me
ENV JWT_EXPIRES_IN=12h
ENV BCRYPT_ROUNDS=10

CMD ["node", "auth.js"]
