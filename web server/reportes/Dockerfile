FROM node:18-alpine

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install --production

COPY . .

EXPOSE 3001

ENV NODE_ENV=production
ENV DB_HOST=localhost
ENV DB_USER=root
ENV DB_PASSWORD=password
ENV DB_NAME=inventario
ENV DB_PORT=3306

CMD ["node", "servidor-reportes.js"]