


FROM python:3.11-alpine3.19



LABEL org.opencontainers.image.title="webapp" \

      org.opencontainers.image.description="DevOps Assessment Web App" \

      org.opencontainers.image.authors="rajujena0" \

      org.opencontainers.image.base.name="python:3.11-alpine3.19"

WORKDIR /app



RUN addgroup -S appgroup && \

    adduser -S -H -D -G appgroup appuser



COPY --chown=appuser:appgroup app.py .



USER appuser



EXPOSE 8080



HEALTHCHECK --interval=30s \

            --timeout=5s \

            --start-period=10s \

            --retries=3 \

            CMD wget -qO- http://localhost:8080/health || exit 1



CMD ["python", "-u", "app.py"]

