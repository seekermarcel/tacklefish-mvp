FROM golang:1.25-alpine AS builder

RUN apk add --no-cache gcc musl-dev

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=1 go build -o /bin/tacklefish ./cmd/server/

# ---

FROM alpine:3.21

RUN apk add --no-cache ca-certificates

COPY --from=builder /bin/tacklefish /bin/tacklefish

RUN mkdir -p /data

ENV DB_PATH=/data/tacklefish.db
ENV ADDR=:8080

EXPOSE 8080

CMD ["/bin/tacklefish"]
