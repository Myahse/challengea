package com.challengea.api.chat;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

interface ConversationRepository extends JpaRepository<Conversation, Long> {
  @Query("""
      select c from Conversation c
      where c.type = 'direct'
        and exists (select 1 from ConversationMember m where m.conversationId = c.id and m.userId = :a)
        and exists (select 1 from ConversationMember m where m.conversationId = c.id and m.userId = :b)""")
  Optional<Conversation> findDirect(long a, long b);
}

interface MemberRepository extends JpaRepository<ConversationMember, Long> {
  List<ConversationMember> findByUserId(long userId);

  List<ConversationMember> findByConversationId(long conversationId);

  Optional<ConversationMember> findByConversationIdAndUserId(long conversationId, long userId);
}

interface MessageRepository extends JpaRepository<ChatMessage, Long> {
  List<ChatMessage> findByConversationIdOrderByIdDesc(long conversationId, Pageable page);

  List<ChatMessage> findByConversationIdAndIdLessThanOrderByIdDesc(long conversationId, long before, Pageable page);

  Optional<ChatMessage> findFirstByConversationIdOrderByIdDesc(long conversationId);

  @Query("""
      select count(m) from ChatMessage m
      where m.conversationId = :conversationId and m.id > :after and (m.senderId is null or m.senderId <> :me)""")
  long countUnread(long conversationId, long after, long me);
}

interface BubbleRepository extends JpaRepository<BubblePosition, Long> {
  List<BubblePosition> findByUserId(long userId);

  Optional<BubblePosition> findByUserIdAndConversationId(long userId, long conversationId);
}
