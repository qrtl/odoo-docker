FROM ubuntu:18.04
LABEL MAINTAINER Quartile Limited <info@quartile.co>

ARG ODOO_SOURCE=OCA/OCB
ARG ODOO_VERSION=10.0

# Update and install all necessary packages
# - `ca-certificates`: Required to securely access archived repositories over HTTPS,
# ensuring SSL/TLS certificate verification and preventing access errors.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Add the PostgreSQL GPG key
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

# Add the PostgreSQL archive repository
RUN echo "deb https://apt-archive.postgresql.org/pub/repos/apt/ bionic-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Update package list
RUN apt-get update

# Install dependencies and tools
RUN set -x; \
  apt-get install -yq --no-install-recommends \
    curl \
    python-pip \
    # Libraries needed to install the pip modules (libpq-dev for pg_config > psycopg2)
    python-dev \
    libpq-dev \
    # to install portable C which is a distant dependency for pysftp 
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libjpeg-dev \
    python-setuptools \
    build-essential \
    # For getting Odoo code
    git

# Install Odoo Python dependencies.
RUN python -m pip install --upgrade pip \
    && pip install -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt

# Install LESS
RUN set -x; \
  apt-get install -y --no-install-recommends \
    node-less \
    node-clean-css

# Install wkhtmltox 0.12.5
RUN apt-get install -y software-properties-common \
    && apt-add-repository -y "deb http://security.ubuntu.com/ubuntu xenial-security main" \
    && apt-get update
ADD https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb /opt/sources/wkhtmltox.deb
RUN set -x; \
  apt-get install -y --no-install-recommends \
    libxrender1 \
    libfontconfig1 \
    libx11-dev \
    libjpeg62 \
    libxtst6 \
    fontconfig \
    xfonts-75dpi \
    xfonts-base \
    libpng12-0 \
    libjpeg-turbo8 \
  && dpkg -i /opt/sources/wkhtmltox.deb \
  && rm -rf /opt/sources/wkhtmltox.deb

# Add odoo user (apply the same in the host machine for compatibility)
RUN addgroup --gid=300 odoo && adduser --system --uid=300 --gid=300 --home /odoo --shell /bin/bash odoo

# Add boot script
COPY ./odooboot /
RUN chmod +x /odooboot

# Change directory owner
RUN chown -R odoo: /odoo

# Install Supervisord.
# For some reason the boot script does not work (container exits...) when it is directly set to entrypoint.
RUN apt-get install -y supervisor
COPY ./supervisord.conf /etc/supervisor/conf.d/

VOLUME ["/odoo", "/usr/share/fonts"]

EXPOSE 8069 8072

ENTRYPOINT ["/usr/bin/supervisord"]
