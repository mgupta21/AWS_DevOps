#!/bin/bash -x
#
# Add config for CloudWatch Logs
# to include cloud-init logs
awsLogsAdd="
[/var/log/cloud-init.log]
datetime_format = %b %d %H:%M:%S
file = /var/log/cloud-init.log
buffer_duration = 5000
log_stream_name = '{instance_id}'
initial_position = start_of_log_file
log_group_name = cloudformation_logs"
#Write to file
echo "$awsLogsAdd" >> /etc/awslogs/awslogs.conf
