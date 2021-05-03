FROM mcr.microsoft.com/dotnet/core/runtime AS build-env

# Install some packages
RUN apt-get update
RUN apt-get install -yq sqlite3 apt-transport-https dirmngr gnupg ca-certificates wget git

# Temp hack
RUN ln -s /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /usr/lib/x86_64-linux-gnu/libsqlite3.so


# Install latest mono from their repo
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF; \
echo "deb https://download.mono-project.com/repo/debian stable-buster main" | tee /etc/apt/sources.list.d/mono-official-stable.list; \
apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'; \
echo "deb http://cloud.r-project.org/bin/linux/debian buster-cran40/" | tee /etc/apt/sources.list.d/r-cran40.list

# Install microsoft's signing key
RUN wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb; \
dpkg -i packages-microsoft-prod.deb; \
rm packages-microsoft-prod.deb

# Update package repos
RUN apt-get update

# Install build dependencies
RUN apt-get install -y git gtk-sharp2 mono-devel dotnet-sdk-3.1

# This environment variable is required for the mono builds to work
ENV FrameworkPathOverride=/usr/lib/mono/4.7.2-api/

# Opt out of microsoft's telemetry program
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1

WORKDIR /apsimbuild

RUN git clone https://github.com/APSIMInitiative/ApsimX.git

WORKDIR /apsimbuild/ApsimX

RUN dotnet build -v m -c Release --nologo ApsimX.sln

FROM mcr.microsoft.com/dotnet/core/runtime

# Install some packages
RUN apt-get update
RUN apt-get install -yq sqlite3

# Copy prebuilt assemblies into the container
COPY --from=build-env /apsimbuild/ApsimX/bin/Release/netcoreapp3.1 /opt/ApsimX/NetCoreBin/

# Temp hack
RUN ln -s /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /usr/lib/x86_64-linux-gnu/libsqlite3.so

WORKDIR /apsim

# Run APSIM
ENTRYPOINT ["dotnet", "/opt/ApsimX/NetCoreBin/Models.dll"]
