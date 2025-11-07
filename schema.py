# type: ignore
# pyright: ignore
from enum import Enum
from pydantic import BaseModel


class $1(BaseModel):
    $2


print($1.model_json_schema())
