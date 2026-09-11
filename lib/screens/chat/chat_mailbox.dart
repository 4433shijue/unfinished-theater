part of '../chat_screen.dart';

class _MailboxDialog extends StatelessWidget {
  const _MailboxDialog();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 640;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 28,
        vertical: compact ? 18 : 32,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? size.width - 20 : 720,
          maxHeight: size.height * 0.82,
        ),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Consumer<AppStateController>(
            builder: (context, controller, _) {
              final mails = controller.mailboxEntries;
              final unclaimed = controller.mailboxUnreadCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppTheme.glitchText('邮箱'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppTheme.glitchText(
                                unclaimed > 0
                                    ? '有 $unclaimed 封奖励邮件待领取。'
                                    : '奖励邮件都已经处理完了。',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.textWeak),
                            ),
                          ],
                        ),
                      ),
                      if (unclaimed > 0)
                        FilledButton.tonal(
                          onPressed: () => _runAction(
                            context,
                            controller.claimAllMailboxRewards,
                            successMessage: '邮箱奖励已全部领取。',
                          ),
                          child: Text(AppTheme.glitchText('全部领取')),
                        ),
                      IconButton(
                        tooltip: AppTheme.glitchText('关闭'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: mails.isEmpty
                        ? const _SoftEmptyLine(
                            text: '邮箱空空，连系统鸽子都没飞过来。',
                          )
                        : ListView.separated(
                            itemCount: mails.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final mail = mails[index];
                              return _MailboxTile(
                                mail: mail,
                                onClaim: () => _runAction(
                                  context,
                                  () => controller.claimMailboxReward(mail.id),
                                  successMessage:
                                      '领取了 ${mail.coins} 啥币，钱包突然精神了。',
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MailboxTile extends StatelessWidget {
  const _MailboxTile({
    required this.mail,
    required this.onClaim,
  });

  final MailboxEntry mail;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final local = mail.createdAt.toLocal();
    final date =
        '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return _GameHubCard(
      icon: mail.claimed
          ? Icons.mark_email_read_outlined
          : Icons.mark_email_unread_outlined,
      title: mail.title,
      subtitle: '${mail.description}\n$date · ${mail.coins}啥币',
      trailing: FilledButton.tonal(
        onPressed: mail.claimed ? null : onClaim,
        child: Text(AppTheme.glitchText(mail.claimed ? '已领取' : '领取')),
      ),
    );
  }
}
