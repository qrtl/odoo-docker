FROM ubuntu:16.04
MAINTAINER Rooms For (Hong Kong) Limited T/A OSCG <contactus@roomsfor.hk>

# Install some dependencies
RUN set -x; \
  apt-get update \
  && apt-get install -y \
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
    # For getting Odoo code
    git

# Install Odoo Python dependencies.
RUN pip install --upgrade pip
ADD requirements.txt /opt/requirements.txt
RUN pip install -r /opt/requirements.txt

# Install LESS
RUN set -x; \
  apt-get install -y --no-install-recommends \
    node-less \
    node-clean-css

# Install wkhtmltopdf 0.12.1
RUN set -x; \
  apt-get install -y fontconfig \
    libx11-6 \
    libxext6 \
    libxrender1
ADD http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb /opt/sources/wkhtmltox.deb
RUN dpkg -i /opt/sources/wkhtmltox.deb \
  && rm -rf /opt/sources/wkhtmltox.deb


# Install postgresql-client
RUN set -x; \
  echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
  apt-get install -y wget ca-certificates && \
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  apt-get update && \
  apt-get install -y postgresql-client-9.5

# Install Japanese fonts for PDF printing
RUN apt-get install fonts-vlgothic

# Add odoo user
RUN adduser --system --home=/opt/odoo --group --shell=/bin/bash odoo

COPY ./odooboot /
RUN chmod +x /odooboot

USER odoo

# `run` to keep PID file
RUN mkdir /opt/odoo/custom-addons \
  && mkdir /opt/odoo/data \
  && mkdir /opt/odoo/etc \
#  && mkdir -p /opt/odoo/var/log
  && mkdir -p /opt/odoo/log
#  && mkdir /opt/odoo/var/run
COPY ./openerp-server.conf /opt/odoo/etc/
#RUN chown -R odoo /opt/odoo/


# Get Odoo code
WORKDIR /opt/odoo
RUN git clone https://github.com/oca/ocb.git -b 9.0 --depth 1 9.0 \
  && rm -rf 9.0/.git


USER 0

# Install Supervisord
RUN apt-get install -y supervisor
COPY ./supervisord.conf /etc/supervisor/conf.d/

VOLUME ["/opt/odoo/custom", "/opt/odoo/data", "/opt/odoo/etc", "/opt/odoo/log"]

EXPOSE 8069 8072


ENTRYPOINT ["/usr/bin/supervisord"]
