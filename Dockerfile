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
    # For database management
    postgresql-client-9.6 \
    # For getting Odoo code
    git

# Install Odoo Python dependencies.
ADD requirements.txt /opt/requirements.txt
RUN python -m pip install --upgrade "pip < 21.0" \
  && pip install -r /opt/requirements.txt

# Install LESS
RUN set -x; \
  apt-get install -y --no-install-recommends \
    node-less \
    node-clean-css

# Install wkhtmltopdf 0.12.5
ADD https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.xenial_amd64.deb /opt/sources/wkhtmltox.deb
RUN set -x; \
  apt-get install -y --no-install-recommends \
    fontconfig \
    libx11-6 \
    libxext6 \
    xfonts-75dpi \
    xfonts-base \
    libxrender1 \
  && dpkg -i /opt/sources/wkhtmltox.deb \
  && rm -rf /opt/sources/wkhtmltox.deb

# Add odoo user (apply the same in the host machine for compatibility)
RUN addgroup --gid=300 odoo && adduser --system --uid=300 --gid=300 --home /odoo --shell /bin/bash odoo

# Add boot script
COPY ./odooboot /
RUN chmod +x /odooboot

# Get Odoo code
WORKDIR /opt
RUN set -x; \
  git clone --depth 1 https://github.com/oca/ocb.git -b 10.0 odoo \
  && rm -rf odoo/.git

# Change directory owner
RUN chown -R odoo: /odoo /opt/odoo

# Install Supervisord.
# For some reason the boot script does not work (container exits...) when it is directly set to entrypoint.
RUN apt-get install -y supervisor
COPY ./supervisord.conf /etc/supervisor/conf.d/

VOLUME ["/odoo", "/usr/share/fonts"]

EXPOSE 8069 8072

ENTRYPOINT ["/usr/bin/supervisord"]
