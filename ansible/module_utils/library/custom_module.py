#!/usr/bin/python

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = ''''''

EXAMPLES = ''''''

RETURN = ''''''

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.custom import CustomUtil

def run_module():
    spec = dict(
        data=dict(type='str', required=True),
    )

    result = dict(changed=False)
    module = AnsibleModule(argument_spec=spec, supports_check_mode=True)

    result['data'] = module.params['data']
    result['response'] = CustomUtil.get_response()

    module.exit_json(**result)

def main():
    run_module()

if __name__ == '__main__':
    main()

