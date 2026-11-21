# Distroless, non-root: the fleet's Go-service image posture
# (go-website-template pattern, minus the node/Tailwind stage).
FROM golang:1.27-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify

RUN go install github.com/a-h/templ/cmd/templ@v0.3.1123

COPY views/ views/
RUN templ generate

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X github.com/example/go-service-template/internal/app.Version=${VERSION:-dev}" \
    -o /out/app ./cmd/app

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /out/app /app
USER nonroot

EXPOSE 8080
ENTRYPOINT ["/app", "serve"]
