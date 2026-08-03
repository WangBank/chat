ARG APP_VERSION=1.0.0-local
ARG VCS_REF=local

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
ARG APP_VERSION

COPY global.json ./
COPY VideoCallAPI.csproj ./
RUN dotnet restore ./VideoCallAPI.csproj

COPY . ./
RUN dotnet publish ./VideoCallAPI.csproj \
    --configuration Release \
    --output /app/publish \
    /p:UseAppHost=false \
    /p:Version="$APP_VERSION" \
    /p:InformationalVersion="$APP_VERSION"

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
ARG APP_VERSION
ARG VCS_REF

LABEL org.opencontainers.image.title="Forever Love Chat API"
LABEL org.opencontainers.image.version=$APP_VERSION
LABEL org.opencontainers.image.revision=$VCS_REF

ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://0.0.0.0:7001
ENV App__Version=$APP_VERSION

EXPOSE 7001

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "VideoCallAPI.dll", "--urls", "http://0.0.0.0:7001"]
