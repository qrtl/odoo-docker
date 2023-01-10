FROM python:3.8-slim-buster
LABEL maintainer="Quartile Limited <info@quartile.co>"

ARG ODOO_SOURCE=OCA/OCB
ARG ODOO_VERSION=14.0
ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM=1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
    dependencies=" \
        curl \
        build-essential \
        dirmngr \
        fonts-noto-cjk \
        git \
        libpq-dev \
        libjpeg-dev \
        liblcms2-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libsasl2-dev \
        libxml2-dev \
        libxslt-dev \
        npm \
        zlib1g-dev \
    " \ 
    && apt-get -qq update \
    && apt-get install -yqq --no-install-recommends $dependencies

RUN python3 -m pip install --upgrade pip \
    && pip install -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
    && apt-get autopurge -yqq

# install latest postgresql-client
RUN set -x; \
    apt-get -qq update \
    && apt-get install -yqq --no-install-recommends gnupg2 \
    && echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
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

VOLUME ["/odoo", "/usr/share/fonts"]

EXPOSE 8069 8071 8072

USER odoo

ENTRYPOINT ["/entrypoint.sh"]
