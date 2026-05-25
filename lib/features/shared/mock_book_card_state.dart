import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_card.dart';

BookCardDownloadState mockDownloadStateFor(MockDownloadStatus status) {
  return switch (status) {
    MockDownloadStatus.downloaded => BookCardDownloadState.downloaded,
    MockDownloadStatus.downloading => BookCardDownloadState.downloading,
    MockDownloadStatus.queued => BookCardDownloadState.queued,
    MockDownloadStatus.paused => BookCardDownloadState.paused,
    MockDownloadStatus.failed => BookCardDownloadState.failed,
  };
}
