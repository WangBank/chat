# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY global.json ./
COPY VideoCallAPI.csproj ./
RUN dotnet restore ./VideoCallAPI.csproj

COPY . ./
RUN dotnet publish ./VideoCallAPI.csproj \
    --configuration Release \
    --output /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://0.0.0.0:7001

EXPOSE 7001

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "VideoCallAPI.dll", "--urls", "http://0.0.0.0:7001"]
