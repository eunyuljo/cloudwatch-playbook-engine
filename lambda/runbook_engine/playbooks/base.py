from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class DiagnosisResult:
    alarm_name: str
    severity: str
    verdict: str
    summary: str
    details: dict = field(default_factory=dict)
    recommended_action: str = ""


class BasePlaybook(ABC):
    @abstractmethod
    def run(self, alarm_message: dict) -> DiagnosisResult:
        pass

    @property
    @abstractmethod
    def alarm_keys(self) -> list:
        pass
