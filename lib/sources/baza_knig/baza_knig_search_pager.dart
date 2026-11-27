// The public Baza Knig search pager advances by 55 hits. Keep the submitted
// offset and the response range check on the same contract.
const bazaKnigSearchPageSize = 55;

int bazaKnigSearchPageStart(int page) =>
    (page - 1) * bazaKnigSearchPageSize + 1;
