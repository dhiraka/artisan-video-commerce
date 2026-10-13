from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    gcp_project_id: str = ""
    gcs_upload_bucket: str = ""
    gcs_output_bucket: str = ""
    transcoder_location: str = "us-central1"
    cors_origins: str = "*"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
