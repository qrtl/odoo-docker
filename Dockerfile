FROM python:3.6-slim-buster
MAINTAINER Quartile Limited <info@quartile.co>

EXPOSE 8069 8071 8072

ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM=1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb
ARG ODOO_SOURCE=odoo/odoo
ARG ODOO_VERSION=14.0
ENV ODOO_VERSION="$ODOO_VERSION"

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get -qq update \
    && apt-get install -yqq --no-install-recommends \
        curl \
        dirmngr \
        git \
        gnupg2 \
        libfreetype6-dev \
        libfribidi-dev \
        libghc-zlib-dev \
        libharfbuzz-dev \
        libjpeg-dev \
        liblcms2-dev \
        libldap2-dev \
        libopenjp2-7-dev \
        libpq-dev \
        libsasl2-dev \
        libtiff5-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt-dev \
        node-less \
        npm \
        tcl-dev \
        tk-dev \
        zlibc \
        zlib1g-dev \
    && curl -SLo wkhtmltox.deb https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.stretch_amd64.deb \
    && echo "${WKHTMLTOPDF_CHECKSUM}  wkhtmltox.deb" | sha256sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
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

ADD requirements.txt /opt/requirements.txt
RUN pip install \
    -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt \
    -r /opt/requirements.txt

# Add odoo user (apply the same in the host machine for compatibility)
RUN addgroup --gid=300 odoo && adduser --system --uid=300 --gid=300 --home /odoo --shell /bin/bash odoo

# Get Odoo code
WORKDIR /opt
RUN set -x; \
  git clone --depth 1 https://github.com/$ODOO_SOURCE.git -b $ODOO_VERSION \
  && rm -rf odoo/.git

# Change directory owner
RUN chown -R odoo: /odoo /opt/odoo

# # Install Supervisord.
# # For some reason the boot script does not work (container exits...) when it is directly set to entrypoint.
# RUN apt-get install -y supervisor
# COPY ./supervisord.conf /etc/supervisor/conf.d/

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

VOLUME ["/odoo", "/usr/share/fonts"]

ENTRYPOINT ["/entrypoint.sh"]
