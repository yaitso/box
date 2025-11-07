from enum import Enum  # noqa: F401
from pydantic import BaseModel


class Class(BaseModel):
    field: str


print(Class.model_json_schema())
