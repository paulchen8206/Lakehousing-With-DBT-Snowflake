FROM python:3.12-slim-bookworm@sha256:4c50375fc4b8ea5ca06ac9485186ccb50171c99390b0e9300c2bac871cc2dc3e

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

COPY infrastructure/docker/requirements.txt /tmp/requirements.txt
COPY infrastructure/docker/constraints.txt /tmp/constraints.txt

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
	&& pip install --no-cache-dir \
		--requirement /tmp/requirements.txt \
		--constraint /tmp/constraints.txt

RUN useradd -m -u 1000 dbt
USER dbt

WORKDIR /opt/dbt
RUN mkdir -p /home/dbt/.dbt /opt/dbt/logs

COPY --chown=dbt:dbt dbt_project /opt/dbt
COPY --chown=dbt:dbt config/profiles.yml /home/dbt/.dbt/profiles.yml

ENTRYPOINT ["sh", "-lc"]
CMD ["dbt deps && dbt debug && dbt run && dbt test"]
