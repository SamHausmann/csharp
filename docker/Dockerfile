FROM rosetteapi/docker-base-layer:latest
MAINTAINER Fiona Hasanaj
ENV LANGUAGE=csharp

#based on dockerfile by Michael Friis <friism@gmail.com>

RUN apt-get update \
	&& apt-get install -y curl \
	&& rm -rf /var/lib/apt/lists/*

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF

RUN echo "deb http://download.mono-project.com/repo/debian wheezy/snapshots/4.2.2.30 main" > /etc/apt/sources.list.d/mono-xamarin.list \
	&& apt-get update \
	&& apt-get install -y mono-devel ca-certificates-mono fsharp mono-vbnc nuget \
	&& rm -rf /var/lib/apt/lists/*


RUN apt-get -y update && apt-get install -y vim && apt-get install -y git && apt-get install -y doxygen && apt-get install -y graphviz
RUN mkdir /test-dev/tests
COPY rosette_api.sln rosette_api.sln

CMD ./docker-entrypoint.sh $API_KEY $FILENAME $ALT_URL $GIT_USERNAME $VERSION $LANGUAGE; /bin/bash
