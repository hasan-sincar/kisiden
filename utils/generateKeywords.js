const stopWords = ['the', 'is', 'in', 'and', 'a', 'to', 'of', 'for', 'on', 'at', 'with', 'by', 'this', 'that', 'or', 'as', 'an', 'from', 'it', 'was', 'are', 'be', 'has', 'have', 'had', 'but', 'if', 'else'];

export const generateKeywords = (description) => {
    if (!description) {
        return process.env.NEXT_PUBLIC_META_kEYWORDS
            ? process.env.NEXT_PUBLIC_META_kEYWORDS.split(",").map((keyword) =>
                keyword.trim()
            )
            : [];
    }

    const words = description
        .toLowerCase()
        .replace(/[^\w\s]/g, "")
        .split(/\s+/);

    const filteredWords = words.filter((word) => !stopWords.includes(word));

    const wordFrequency = filteredWords.reduce((acc, word) => {
        acc[word] = (acc[word] || 0) + 1;
        return acc;
    }, {});

    const sortedWords = Object.keys(wordFrequency).sort(
        (a, b) => wordFrequency[b] - wordFrequency[a]
    );

    return sortedWords.slice(0, 10);
};