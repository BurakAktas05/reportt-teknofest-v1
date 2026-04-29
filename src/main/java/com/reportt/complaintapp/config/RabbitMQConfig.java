package com.reportt.complaintapp.config;

import org.springframework.amqp.core.Queue;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {
    public static final String MEDIA_ANALYSIS_QUEUE = "media.analysis.queue";

    @Bean
    public Queue mediaAnalysisQueue() {
        return new Queue(MEDIA_ANALYSIS_QUEUE, true);
    }

    @Bean
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }
}
