FROM ubuntu:16.04
MAINTAINER Rooms For (Hong Kong) Limited T/A OSCG <contactus@roomsfor.hk>

# Update source repository
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update

# Install dependencies and tools
RUN set -x; \
  apt-get install -yq --no-install-recommends \
    python-pip \
    python-imaging \
    python-pychart \
    # Libraries needed to install the pip modules (libpq-dev for pg_config > psycopg2)
    libpq-dev \
    python-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libjpeg-dev \
    python-setuptools \
    build-essential \
    # For database management
    postgresql-client-9.5 \
    # For getting Odoo code
    git   

# Install Odoo Python dependencies.
ADD requirements.txt /opt/requirements.txt
RUN pip install --upgrade pip \
  && pip install -r /opt/requirements.txt

# Install LESS
RUN set -x; \
  apt-get install -y --no-install-recommends \
    node-less \
    node-clean-css

# Install wkhtmltopdf 0.12.1
ADD http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb /opt/sources/wkhtmltox.deb
RUN set -x; \
  apt-get install -y --no-install-recommends \
    fontconfig \
    libx11-6 \
    libxext6 \
    libxrender1 \
  && dpkg -i /opt/sources/wkhtmltox.deb \
  && rm -rf /opt/sources/wkhtmltox.deb

# Install Japanese fonts for PDF printing
RUN apt-get install fonts-vlgothic

# Add odoo user
RUN adduser --system --home=/opt/odoo --group --shell=/bin/bash odoo

# Add boot script
COPY ./odooboot /
RUN chmod +x /odooboot

USER odoo

# `Create directories
RUN bin/bash -c "mkdir /opt/odoo/{custom,data,etc,log}"
COPY ./openerp-server.conf /opt/odoo/etc/

# Get Odoo code
WORKDIR /opt/odoo
RUN set -x; \
  git clone --depth 1 https://github.com/oca/ocb.git -b 9.0 9.0 \
  && rm -rf 9.0/.git

USER 0

# Install Supervisord.
# For some reason the boot script does not work (container exits...) when it is directly set to entrypoint.
RUN apt-get install -y supervisor
COPY ./supervisord.conf /etc/supervisor/conf.d/

VOLUME ["/opt/odoo/custom", "/opt/odoo/data", "/opt/odoo/etc", "/opt/odoo/log"]

EXPOSE 8069 8072

ENTRYPOINT ["/usr/bin/supervisord"]
