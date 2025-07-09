FROM python:3.10-slim-bookworm
LABEL maintainer="Quartile <info@quartile.co>"

ARG ODOO_SOURCE=OCA/OCB
ARG ODOO_VERSION=18.0
ARG WKHTMLTOPDF_VERSION=0.12.6.1
ARG WKHTMLTOPDF_CHECKSUM='98ba0d157b50d36f23bd0dedf4c0aa28c7b0c50fcdcdc54aa5b6bbba81a3941d'

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

RUN set -x; \
    apt-get -qq update \
    && apt-get install -yqq --no-install-recommends \
        curl \
        git

RUN set -x; \
    # libjpeg8-dev is not available in Debian, therefore libjpeg-dev
    dependencies=" \
        build-essential \
        python3-dev \
        libxml2-dev \
        libxslt1-dev \
        libldap2-dev \
        libsasl2-dev \
        libtiff5-dev \
        libjpeg-dev \
        libopenjp2-7-dev \
        zlib1g-dev \
        libfreetype6-dev \
        liblcms2-dev \
        libwebp-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libxcb1-dev \
        libpq-dev \
    " \ 
    && apt-get -qq update \
    && apt-get install -yqq --no-install-recommends $dependencies

RUN python3 -m pip install --upgrade pip \
    && curl -o requirements.txt https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
    # disable gevent version recommendation from odoo and use 22.10.2 used in debian bookworm as python3-gevent
    && sed -i -E "s/(gevent==)21\.8\.0( ; sys_platform != 'win32' and python_version == '3.10')/\122.10.2\2/;s/(greenlet==)1.1.2( ; sys_platform != 'win32' and python_version == '3.10')/\12.0.2\2/" requirements.txt \
    && pip install -r requirements.txt \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}-3/wkhtmltox_${WKHTMLTOPDF_VERSION}-3.bookworm_amd64.deb \
    # Two spaces between '-c' and '-' below: https://unix.stackexchange.com/a/139892
    && echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c  - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
    && apt-get autopurge -yqq

# Install the latest postgresql-client
RUN set -x; \
    apt-get -qq update \
    && apt-get install -yqq --no-install-recommends gnupg2 \
    && echo 'deb http://apt.postgresql.org/pub/repos/apt/ bookworm-pgdg main' >> /etc/apt/sources.list.d/postgresql.list \
    && curl -SL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/postgresql.list \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autopurge -yqq \
    && sync

# Add odoo user (apply the same in the host machine for compatibility)
RUN addgroup --gid=300 odoo && adduser --system --uid=300 --gid=300 --home /odoo --shell /bin/bash odoo

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Change directory owner
RUN chown -R odoo: /odoo /usr/local/bin/wait-for-psql.py

# Set the default config file
ENV ODOO_RC /odoo/etc/odoo.conf

VOLUME ["/odoo", "/usr/share/fonts", "/mnt"]

EXPOSE 8069 8072

USER odoo

ENTRYPOINT ["/entrypoint.sh"]
