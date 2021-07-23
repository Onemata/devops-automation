#!/bin/bash


##  The following VARs should be set
#PROFILE="${bamboo.AWS_PROFILE_SQS}"
#REGION="${bamboo.AWS_REGION}"
#SQS_URL="${bamboo.inject.SQS_URL}"

isSQSQueueEmpty () {
    for (( i=1; i<=5; i++ ));
    do
        Messages=`aws --profile ${PROFILE} --region ${REGION} sqs get-queue-attributes --queue-url "${SQS_URL}" --attribute-names ApproximateNumberOfMessages --query 'Attributes.[ApproximateNumberOfMessages]' --output text`
        MessagesNotVisable=`aws --profile ${PROFILE} --region ${REGION} sqs get-queue-attributes --queue-url "${SQS_URL}" --attribute-names ApproximateNumberOfMessagesNotVisible --query 'Attributes.[ApproximateNumberOfMessagesNotVisible]' --output text`
        if [[ "${Messages}" -eq 0 ]] && [[ "${MessagesNotVisable}" -eq 0 ]]; then
            echo "==========================="
            echo "Queue is empty"
            echo "==========================="
            exit 0
        fi
        echo "==========================="
        echo "Queue still has ${Messages} messages."
        echo "Queue still has ${MessagesNotVisable} messages not visible."
        sleep 15

    done

    echo "Queue is not empty.  Failing Job"
    return 1

}

deleteSQSQueue () {
    isSQSQueueEmpty
    if [[ $? -eq 0 ]] ; then
        aws --profile ${PROFILE} --region ${REGION} sqs delete-queue --queue-url  ${SQS_URL}
        return $?
    else
        return 1
    fi
}

CheckStatusOfTasks () {
    STATUS="STOPPED"
    for taskResource in ${RESOURCES//;/ } ; do
        #echo "${taskResource}"
        taskResourceArn="${TASK_BASE_ARN}/${taskResource}"
        echo "Checking Task: ${taskResourceArn}"
        STATUS=`aws --region ${REGION} --profile ${PROFILE} ecs describe-tasks  --cluster ${CLUSTER_ARN} --tasks ${taskResourceArn} --query 'tasks[*].{lastStatus: lastStatus}' --output text`
        if [[ "${STATUS}" == "RUNNING" ]] ; then
            break
        fi
    done
}

areTasksRunning () {
    STATUS="RUNNING"
    until [[ "${STATUS}" == "STOPPED" ]] ; do

        CheckStatusOfTasks
        if [[ "${STATUS}" == "RUNNING" ]] ; then
            echo "Tasks are still running... Sleeping 30 seconds"
            sleep 30
        fi

    done
}

case "$1" in
    "") exit ;;
    isSQSQueueEmpty) "@"; exit $?;;
    deleteSQSQueue) "@"; exit $?;;
    areTasksRunning) "@"; exit $?;;
    *) echo "unkown function" ; exit 2;;
esac

