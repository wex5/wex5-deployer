FROM hub.cloudx5.com/java:8-jre

RUN apt-get update && apt-get install -y --no-install-recommends \
		zip \
		unzip \
		ca-certificates \
		curl \
		wget \
	&& rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /usr/local/bin/
COPY env.sh /usr/local/bin/
COPY common.sh /usr/local/bin/
COPY init-product.sh /usr/local/bin/
COPY init-service.sh /usr/local/bin/
COPY init-gateway.sh /usr/local/bin/
COPY init.sh /usr/local/bin/
COPY clean.sh /usr/local/bin/
COPY agent-1.0.1.jar /usr/local/agent/
RUN ln -s /usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
CMD ["docker-entrypoint.sh"]
