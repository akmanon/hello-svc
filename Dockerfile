# syntax=docker/dockerfile:1

############################
# Stage 1: build
############################
FROM golang:1.24-alpine AS build
WORKDIR /src

# Dependency files first: this layer is rebuilt only when go.mod/go.sum change.
COPY go.mod ./
# go.sum is optional for a module with no dependencies; add it here when you have one.
RUN --mount=type=cache,target=/go/pkg/mod go mod download

# Source last: changes here do not invalidate the dependency layer above.
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/server .

############################
# Stage 2: runtime
############################
# distroless static: no shell, no package manager, CA certs included, runs as non-root.
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/server /server

ENV PORT=8080
EXPOSE 8080
USER nonroot:nonroot

# Exec form: the server is PID 1 and receives SIGTERM directly (it handles it; see main.go).
ENTRYPOINT ["/server"]
