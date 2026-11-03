FROM dart:3.13.7-sdk AS build
WORKDIR /workspace
COPY packages/game_core/ packages/game_core/
COPY server/pubspec.yaml server/pubspec.lock server/
WORKDIR /workspace/server
RUN dart pub get --enforce-lockfile
COPY server/ ./
RUN dart pub get --offline --enforce-lockfile \
    && dart analyze \
    && mkdir -p /app \
    && dart compile exe bin/server.dart -o /app/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
USER 65532:65532
WORKDIR /app
ENV HOST=0.0.0.0 PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/server"]
