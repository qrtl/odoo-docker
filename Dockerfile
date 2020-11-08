FROM debian:buster-slim
LABEL maintainer="Quartile Limited <info@quartile.co>"

ARG ODOO_SOURCE=odoo/odoo
ARG ODOO_VERSION=14.0
ARG WKHTMLTOPDF_VERSION=0.12.5
ARG WKHTMLTOPDF_CHECKSUM=1140b0ab02aa6e17346af2f14ed0de807376de475ba90e1db3975f112fbd20bb
ARG ODOO_SOURCE=odoo/odoo
ARG ODOO_VERSION=14.0

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
    dependencies=" \
        curl \
        build-essential \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        git \
        libssl-dev \
        node-less \
        npm \
        python3-dev \
        python3-num2words \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils \
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

# Clean up apt cache
RUN rm -rf /var/lib/apt/lists/* && apt autoremove -yqq

# Add odoo user (apply the same in the host machine for compatibility)
RUN addgroup --gid=300 odoo && adduser --system --uid=300 --gid=300 --home /odoo --shell /bin/bash odoo

# Get Odoo code
WORKDIR /opt
RUN git clone --depth 1 https://github.com/$ODOO_SOURCE.git -b $ODOO_VERSION

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Change directory owner
RUN chown -R odoo: /odoo /opt/odoo /usr/local/bin/wait-for-psql.py

# Set the default config file
ENV ODOO_RC /odoo/etc/odoo.conf

VOLUME ["/odoo", "/usr/share/fonts"]

EXPOSE 8069 8071 8072

USER odoo

ENTRYPOINT ["/entrypoint.sh"]
