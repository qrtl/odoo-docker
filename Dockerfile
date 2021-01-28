FROM ubuntu:18.04
LABEL maintainer="Quartile Limited <info@quartile.co>"

ARG PYTHON_VERSION=3.6
ARG ODOO_SOURCE=odoo/odoo
ARG ODOO_VERSION=14.0
ARG WKHTMLTOPDF_VERSION=0.12.5

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG C.UTF-8

# Python package management and basic dependencies
RUN apt-get -qq update
RUN apt-get install -yqq --no-install-recommends python$PYTHON_VERSION python$PYTHON_VERSION-dev python$PYTHON_VERSION-distutils

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN set -x; \
    dependencies=" \
        curl \
        python3-pip \
        # Libraries needed to install the pip modules (libpq-dev for pg_config > psycopg2)
        python3-setuptools \
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
    && apt-get install -yqq --no-install-recommends $dependencies

# Install wkhtmltox 0.12.5
RUN apt-get install -y software-properties-common \
    && apt-add-repository -y "deb http://security.ubuntu.com/ubuntu xenial-security main" \
    && apt-get update
ADD https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}-1.xenial_amd64.deb /opt/sources/wkhtmltox.deb
RUN set -x; \
    apt-get install -y --no-install-recommends \
        libxrender1 \
        libfontconfig1 \
        libx11-dev \
        libjpeg62 \
        libxtst6 \
        node-less \
        fontconfig \
        xfonts-75dpi \
        xfonts-base \
        libpng12-0 \
        libjpeg-turbo8 \
    && dpkg -i /opt/sources/wkhtmltox.deb \
    && rm -rf /opt/sources/wkhtmltox.deb

# Set specific version as the default python and python3
RUN update-alternatives --install /usr/bin/python python /usr/bin/python$PYTHON_VERSION 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python$PYTHON_VERSION 1
RUN update-alternatives --set python /usr/bin/python$PYTHON_VERSION
RUN update-alternatives --set python3 /usr/bin/python$PYTHON_VERSION

RUN python3 -m pip install --upgrade pip \
    && pip install -r https://raw.githubusercontent.com/$ODOO_SOURCE/$ODOO_VERSION/requirements.txt

# Update source repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update
RUN apt-get install --no-install-recommends -y postgresql-client-10

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
