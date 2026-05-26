from .alb_target_5xx import AlbTarget5xxPlaybook

_PLAYBOOKS = {}


def _register(playbook_class):
    instance = playbook_class()
    for key in instance.alarm_keys:
        _PLAYBOOKS[key] = instance


_register(AlbTarget5xxPlaybook)


class PlaybookRegistry:
    @staticmethod
    def get(alarm_key: str):
        return _PLAYBOOKS.get(alarm_key)
